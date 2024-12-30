open! Core
module B = Bytes
module Write = Eio.Buf_write
module KVStore = Kvstore

(* TODO: This records for each client the number of its most ercent request, plus if the request has been executed, the reusult for that request*)
(* TODO: Reason about performance, should not be problem, could just use mutable if need be. *)
module State = struct
  module Status = struct
    type t =
      | Normal
      | ViewChange
      | Recovering
    [@@deriving bin_io, sexp]
  end

  module ClientTable = struct
    module RequestRecord = struct
      type t =
        { last_request_id : int
        ; last_result : Operation.result option (* None implies not executed*)
        }
      [@@deriving sexp, compare]
    end

    type t = (int, RequestRecord.t) Hashtbl.t [@@deriving sexp_of]

    let create () : t = Hashtbl.create (module Int)
  end

  type t =
    { configuration : Configuration.t
        (* TODO: make sure that the invariant holds for the index when updating config. *)
    ; replica_number : int (* This is the index into its IP in configuration *)
    ; view_number : int (* Initially 0 *)
    ; status : Status.t
    ; op_number : int (* Initially 0, the most recently recieved request *)
    ; log : Log.t (* Ordered list of operations *)
    ; commit_number : int (* The most recent commited op_number *)
    ; client_table : ClientTable.t
    ; store : KVStore.t
    }
  [@@deriving sexp_of]

  let get_primary s = s.view_number % Configuration.length s.configuration
  let is_primary s = Int.equal s.replica_number (get_primary s)
  let get_majority s = (Configuration.length s.configuration / 2) + 1

  (** Advances op_number, then appends entry to log. *)
  let enqueue_log (s : t) req =
    let s = { s with op_number = s.op_number + 1 } in
    let entry = Log.{ req; op_number = s.op_number } in
    Log.append_entry s.log entry;
    s
  ;;

  let add_client s =
    let new_client =
      Hashtbl.keys s.client_table
      |> List.max_elt ~compare:Int.compare
      |> Option.value_map ~f:(( + ) 1) ~default:0
    in
    Hashtbl.add_exn
      s.client_table
      ~key:new_client
      ~data:{ last_request_id = 0; last_result = None };
    Utils.log_info (sprintf "Client %d joined" new_client);
    new_client
  ;;

  (** None represents not executed *)
  let update_client s ~client_id ~op_number result =
    Hashtbl.set
      s.client_table
      ~key:client_id
      ~data:{ last_request_id = op_number; last_result = result }
  ;;
end

open State

let drop_request () = ()

(* let create_response (state : State.t) (req : Message.Request.t) =
  let result =
    ((match req.operation with
      | Join -> Message.Reply.Join { client_id = state. }
      | Add _ -> Message.Reply.Add { done_todo = true }
      | Update _ -> assert false
      | Remove _ -> assert false)
     : Message.Reply.result)
  in
  Message.Reply.
    { view_number = state.view_number; request_number = req.request_number; result }
;; *)

let send_message resp connection =
  let buf = Message.to_bytes resp in
  Write.with_flow connection (fun to_server -> Write.bytes to_server buf);
  Utils.log_info_sexp ~msg:"Sending: " (Message.sexp_of_t resp)
;;

let send_client_reply reply conn =
  let writer_response = [%bin_writer: Message.Reply.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_response reply in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  Write.with_flow conn (fun to_server -> Write.bytes to_server buf);
  Utils.log_info_sexp ~msg:"Sending: " (Message.Reply.sexp_of_t reply)
;;

let send_prepare_to_backups ~sw ~env state message =
  let ips = Configuration.to_list state.configuration in
  let primary_i = State.get_primary state in
  let non_primary = List.filteri ips ~f:(fun i _ -> not (Int.equal i primary_i)) in
  let prepare =
    Message.Replica.Prepare
      { view_number = state.view_number
      ; message
      ; op_number = state.op_number
      ; commit_number = state.commit_number
      }
  in
  let send_to_replica addr =
    let net = Eio.Stdenv.net env in
    let connection = Eio.Net.connect ~sw net (`Tcp addr) in
    send_message (Message.Replica_message prepare) connection;
    connection
  in
  Eio.Fiber.List.map send_to_replica non_primary
;;

let init_state ~addresses ~replica_address =
  let module IPs = Configuration in
  let configuration = addresses in
  let replica_number =
    IPs.find_addr replica_address configuration |> Option.value ~default:0
  in
  State.
    { configuration
    ; replica_number
    ; view_number = 0
    ; status = State.Status.Normal
    ; op_number = 0
    ; log = Log.create_log ~initial_length:1024 ()
    ; commit_number = 0
    ; client_table = State.ClientTable.create ()
    ; store = KVStore.create ()
    }
;;

let receive_message connection =
  let reader_request = [%bin_reader: Message.t] in
  let msg =
    Bin_prot.Utils.bin_read_stream reader_request ~read:(fun buf ~pos ~len ->
      let c = Cstruct.create len in
      Eio.Flow.read_exact connection c;
      Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
  in
  Utils.log_info_sexp ~msg:"Recieved: " (Message.sexp_of_t msg);
  msg
;;

let execute_operation state (entry : Log.entry) =
  assert (entry.op_number <= state.op_number);
  Utils.assert_int [%here] ( > ) entry.op_number state.commit_number;
  match entry.req.op with
  | Operation.Add { key; value } ->
    KVStore.set state.store ~key ~value;
    Operation.AddResult (Ok ())
  (* TODO: decide on the semantical difference between add and update, just call it Set? *)
  | Operation.Update { key; value } ->
    KVStore.set state.store ~key ~value;
    Operation.UpdateResult (Ok ())
  | Operation.Remove { key } ->
    KVStore.remove state.store ~key;
    Operation.RemoveResult (Ok ())
  | Operation.Join ->
    let new_client_id = State.add_client state in
    Operation.JoinResult (Ok new_client_id)
;;

let primary_commit_and_reply state conn =
  (* let state = State.{ state with commit_number = state.op_number } in *)
  let rec go state =
    if state.op_number > state.commit_number
    then (
      let next_op = Log.get_log_entry state.log state.op_number in
      let result = execute_operation state next_op in
      let state = { state with commit_number = next_op.op_number } in
      let reply =
        Message.Reply.
          { view_number = state.view_number
          ; request_number = next_op.req.request_number
          ; result
          }
      in
      send_client_reply reply conn;
      go state)
    else state
  in
  Utils.log_info "Committed and replied";
  go state
;;

let do_consensus ~sw ~env state client_req =
  assert (State.is_primary state);
  if State.get_majority state > 1
  then (
    let connections = send_prepare_to_backups ~sw ~env state client_req in
    let majority = State.get_majority state in
    assert (List.length connections >= majority);
    let p, u = Eio.Promise.create () in
    let prepare_ok_count = ref 0 in
    List.iter
      ~f:(fun conn ->
        Eio.Fiber.fork ~sw (fun () ->
          match receive_message conn with
          | Message.Replica_message (PrepareOk _) ->
            (* TODO: validate below *)

            (* if op_number = state.op_number && view_number = state.view_number *)
            (* then *)
            prepare_ok_count := !prepare_ok_count + 1;
            if !prepare_ok_count >= majority then Eio.Promise.resolve u ()
          | _ ->
            raise_s [%message "TODO: a client request, put it in a queue" ~here:[%here]]))
      connections;
    Eio.Promise.await p);
  Utils.log_info "Consensus done"
;;

let resend_last_response v r conn response =
  match response with
  | None -> ()
  | Some req ->
    let reply =
      Message.Reply.{ view_number = v; request_number = r; result = req.result }
    in
    send_client_reply reply conn
;;

(** request_number < last_request_id -> the request is outdated

    request_number = last_request_id -> resend the previous response

    request_numbber > last_request_id -> handle the request normally *)
let handle_client_request ~env ~sw state (req : Message.Request.t) conn =
  match req.op with
  | Operation.Join ->
    let state = State.enqueue_log state req in
    do_consensus ~sw ~env state req;
    (* Now that majority has been reached, time to commit. *)
    let state = primary_commit_and_reply state conn in
    state
  | _ ->
    (match Hashtbl.find state.client_table req.client_id with
     | None ->
       raise_s [%message (sprintf "client %d not in table" req.client_id) ~here:[%here]]
     | Some v ->
       let reply result =
         Message.Reply.
           { view_number = state.view_number
           ; request_number = req.request_number
           ; result
           }
       in
       if req.request_number < v.last_request_id
       then (
         send_client_reply (reply Outdated) conn;
         state)
       else if req.request_number < v.last_request_id
       then
         raise_s [%message "TOOD" ~here:[%here]]
         (* TODO *)
         (* resend_last_response
            state.view_number
            req.request_number
            conn
            (reply v.last_result) *)
       else (
         let state = State.enqueue_log state req in
         do_consensus ~sw ~env state req;
         (* Now that majority has been reached, time to commit. *)
         let state = primary_commit_and_reply state conn in
         state))
;;

let handle_message ~sw ~env state connection =
  let request = receive_message connection in
  let state =
    match request with
    | Message.Client_request req ->
      (match State.is_primary state with
       | false ->
         raise_s [%message "TODO: A non priary replica got client req..?" ~here:[%here]]
       | true -> handle_client_request ~sw ~env state req connection)
    | Message.Replica_message (Prepare { view_number; op_number; message; _ }) ->
      assert (view_number >= state.view_number);
      assert (not @@ State.is_primary state);
      (* If the op_number is 1, that means it's the first Prepare, no need to wait *)
      if op_number > state.op_number && not (op_number = 1)
      then raise_s [%message "replica is ahead" ~here:[%here]]
      else if op_number < state.op_number
      then raise_s [%message "TODO: replica is behind" ~here:[%here]]
      else (
        let state = State.enqueue_log state message in
        State.update_client state ~client_id:message.client_id ~op_number None;
        let prepare_ok =
          Message.Replica.PrepareOk
            { view_number; op_number; replica_number = state.replica_number }
        in
        send_message (Message.Replica_message prepare_ok) connection;
        state)
    | Message.Replica_message _ -> raise_s [%message "TODO" ~here:[%here]]
  in
  state
;;

let on_error e =
  Logs.err (fun f -> f "%s\n%s" (Exn.to_string e) (Printexc.get_backtrace ()))
;;

let run_replica ~env ~sw addresses replica_address =
  let net = Eio.Stdenv.net env in
  let socket =
    Eio.Net.listen ~reuse_addr:true ~sw net (`Tcp replica_address) ~backlog:1024
  in
  while true do
    Eio.Net.accept_fork ~sw ~on_error socket (fun connection _ ->
      let state = init_state ~addresses ~replica_address in
      let rec continue state =
        try handle_message ~sw ~env state connection |> continue with
        | End_of_file | Core_unix.Unix_error _ -> Utils.log_info "Closed | Unix_error"
      in
      continue state)
  done
;;

let start addresses replica_address =
  Utils.setup_log ();
  Utils.log_info_sexp
    [%message
      "" (sprintf !"Starting replica on %{sexp:Configuration.addr}" replica_address)];
  Eio_main.run (fun env ->
    Eio.Switch.run (fun sw -> run_replica ~env ~sw addresses replica_address))
;;

let%expect_test "tt" =
  let inet = Core_unix.Inet_addr.of_string "127.0.0.1" in
  let state =
    init_state
      ~addresses:Configuration.empty
      ~replica_address:(Eio_unix.Net.Ipaddr.of_unix inet, 3000)
  in
  [%expect {| |}];
  let client_id = State.add_client state in
  print_s (State.ClientTable.sexp_of_t state.client_table);
  [%expect {| ((0 ((last_request_id 0) (last_result ())))) |}];
  State.update_client state ~client_id ~op_number:1 (Some Operation.Outdated);
  print_s (State.ClientTable.sexp_of_t state.client_table);
  [%expect {| ((0 ((last_request_id 1) (last_result (Outdated))))) |}]
;;

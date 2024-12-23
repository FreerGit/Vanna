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

  module Log = struct
    type entry =
      { op : Operation.t
      ; op_number : int
      }
    [@@deriving sexp]

    type t = entry Queue.t [@@deriving sexp]
  end

  module ClientTable = struct
    module RequestRecord = struct
      type t =
        { last_request_id : int
        ; last_result : Message.Client_response.t option (* None implies not executed*)
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
    ; last_client_id : int (* Last client that joined the network, not in paper *)
    ; store : KVStore.t
    }
  [@@deriving sexp_of]

  let get_primary s = s.view_number % Configuration.length s.configuration
  let is_primary s = Int.equal s.replica_number (get_primary s)
  let get_majority s = (Configuration.length s.configuration / 2) + 1

  (**     
     Advances op_number, then appends entry to log.
  *)
  let enqueue_log state (op : Operation.t) =
    let state = { state with op_number = state.op_number + 1 } in
    let entry = Log.{ op; op_number = state.op_number } in
    Queue.enqueue state.log entry;
    state
  ;;

  let apply_from_log state =
    match Queue.peek state.log with
    | None -> raise_s [%message "Log was empty when trying to commit!"]
    | Some entry -> entry
  ;;

  let add_client s =
    let state = { s with last_client_id = s.last_client_id + 1 } in
    Hashtbl.add_exn
      state.client_table
      ~key:state.last_client_id
      ~data:{ last_request_id = 0; last_result = None };
    Utils.log_info (sprintf "Client %d joined" state.last_client_id)
  ;;

  (** None represents not executed *)
  let update_client s ~client_id ~op_number result =
    Hashtbl.set
      s.client_table
      ~key:client_id
      ~data:{ last_request_id = op_number; last_result = result }
  ;;
end

let drop_request () = ()

let create_response (state : State.t) (req : Message.Client_request.t) =
  match req.operation with
  | Join -> Message.Client_response.Join { client_id = state.last_client_id }
  | Add _ -> Message.Client_response.Add { done_todo = true }
  | Update _ -> assert false
  | Remove _ -> assert false
;;

let send_message resp connection =
  let writer_response = [%bin_writer: Message.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_response resp in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  Write.with_flow connection (fun to_server -> Write.bytes to_server buf);
  Utils.log_info_sexp ~msg:"Sending: " (Message.sexp_of_t resp)
;;

let send_client_message resp connection =
  let writer_response = [%bin_writer: Message.Client_response.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_response resp in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  Write.with_flow connection (fun to_server -> Write.bytes to_server buf);
  Utils.log_info_sexp ~msg:"Sending: " (Message.Client_response.sexp_of_t resp)
;;

let send_prepare_to_backups ~sw ~env (state : State.t) message =
  let ips = Configuration.to_list state.configuration in
  let primary_i = State.get_primary state in
  let non_primary = List.filteri ips ~f:(fun i _ -> not (Int.equal i primary_i)) in
  let prepare =
    Message.Replica_message.Prepare
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

(* https://chatgpt.com/c/67642853-a348-8006-b355-d00edcabd5ac *)

(* let handle_request ~sw ~env (state : State.t) (r : Message.Client_request.t) =
  Utils.log_info "handle_request";
  if Operation.compare r.operation Join = 0
  then (
    let state = send_prepare ~sw ~env state r in
    let state = add_client state in
    Some (create_response state r))
  else (
    match Hashtbl.find state.client_table r.client_id with
    | None -> raise_s [%message (sprintf "client %d not in table" r.client_id) [%here]]
    | Some v ->
      Utils.log_info
        (sprintf "%d %d" (compare r.request_number v.last_request_id) r.request_number);
      (match compare r.request_number v.last_request_id with
       | x when x < 0 ->
         drop_request ();
         None
       | 0 ->
         drop_request ();
         (match v.last_result with
          | None -> ()
          | Some r -> resend_last_response r);
         None
       | _ -> Some (create_response state r)))
;; *)

let init_state ~addresses ~replica_address : State.t =
  let module IPs = Configuration in
  let configuration = addresses in
  let replica_number =
    IPs.find_addr replica_address configuration |> Option.value ~default:0
  in
  { configuration
  ; replica_number
  ; view_number = 0
  ; status = State.Status.Normal
  ; op_number = 0
  ; log = Queue.create ()
  ; commit_number = 0
  ; client_table = State.ClientTable.create ()
  ; last_client_id = 0
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

(* Lastly, to reflect the commit, set the commit_number to op_number. That way backups
   can commit what they have in the log (upto and including the commit_number)
*)

let primary_commit state =
  assert (State.is_primary state);
  let entry = State.apply_from_log state in
  (match entry.op with
   | Operation.Add { key; value } -> KVStore.set state.store ~key ~value
   (* TODO: decide on the semantical difference between add and update, just call it Set? *)
   | Operation.Update { key; value } -> KVStore.set state.store ~key ~value
   | Operation.Remove { key } -> KVStore.remove state.store ~key
   | Operation.Join -> State.add_client state);
  State.{ state with commit_number = entry.op_number }
;;

let do_consensus ~sw ~env (state : State.t) client_req =
  assert (State.is_primary state);
  if State.get_majority state > 1
  then (
    let connections = send_prepare_to_backups ~sw ~env state client_req in
    let majority = State.get_majority state in
    assert (List.length connections >= majority);
    let prepare_ok_count = ref 0 in
    let recieve_closure = List.map ~f:(fun conn () -> receive_message conn) connections in
    (* TODO: timeout? failure case? *)
    while !prepare_ok_count < majority do
      Utils.log_info (sprintf "waiting for OK %d %d" !prepare_ok_count majority);
      (* Wait for PrepareOk from replicas *)
      match Eio.Fiber.any recieve_closure with
      | Message.Replica_message (PrepareOk _) ->
        (* TODO: validate below *)

        (* if op_number = state.op_number && view_number = state.view_number *)
        (* then *)
        prepare_ok_count := !prepare_ok_count + 1
      | _ -> raise_s [%message "TODO: a client request, put it in a queue" ~here:[%here]]
    done);
  (* Now that majority has been reached, time to commit. *)
  primary_commit state
;;

let resend_last_response conn response =
  match response with
  | None -> ()
  | Some r -> send_client_message r conn
;;

(** 
  request_number < last_request_id -> the request is outdated
  
  request_number = last_request_id -> resend the previous response
  
  request_numbber > last_request_id -> handle the request normally
*)
let handle_client_request ~env ~sw (state : State.t) (req : Message.Client_request.t) conn
  =
  match req.operation with
  | Operation.Join ->
    let state = State.enqueue_log state req.operation in
    let state = do_consensus ~sw ~env state req in
    let response = create_response state req in
    send_client_message response conn
  | _ ->
    (match Hashtbl.find state.client_table req.client_id with
     | None ->
       raise_s [%message (sprintf "client %d not in table" req.client_id) ~here:[%here]]
     | Some v ->
       if req.request_number < v.last_request_id
       then send_client_message Outdated conn
       else if req.request_number < v.last_request_id
       then resend_last_response conn v.last_result
       else (
         let state = State.enqueue_log state req.operation in
         let response = create_response state req in
         let state = do_consensus ~sw ~env state req in
         let new_record =
           State.ClientTable.RequestRecord.
             { last_request_id = req.request_number; last_result = Some response }
         in
         Hashtbl.set state.client_table ~key:req.client_id ~data:new_record;
         send_client_message response conn))
;;

let handle_message ~sw ~env (state : State.t) connection =
  let request = receive_message connection in
  (match request with
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
       let state = State.enqueue_log state message.operation in
       State.update_client state ~client_id:message.client_id ~op_number None;
       let prepare_ok =
         Message.Replica_message.PrepareOk
           { view_number; op_number; replica_number = state.replica_number }
       in
       send_message (Message.Replica_message prepare_ok) connection)
   | Message.Replica_message _ -> raise_s [%message "TODO" ~here:[%here]]);
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
  State.add_client state;
  print_s (State.ClientTable.sexp_of_t state.client_table);
  [%expect {| ((1 ((last_request_id 0) (last_result ())))) |}];
  State.update_client
    state
    ~client_id:1
    ~op_number:1
    (Some Message.Client_response.Outdated);
  print_s (State.ClientTable.sexp_of_t state.client_table);
  [%expect {| ((1 ((last_request_id 1) (last_result (Outdated))))) |}]
;;

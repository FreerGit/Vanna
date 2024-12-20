open! Core
module B = Bytes
module Write = Eio.Buf_write

module Status = struct
  type t =
    | Normal
    | ViewChange
    | Recovering
  [@@deriving bin_io, sexp]
end

module ClientTable = struct
  module RequstRecord = struct
    type t =
      { last_request_id : int
      ; last_result : int option (* None implies not executed*)
      }
    [@@deriving sexp, hash, compare]
  end

  type t = (int, RequstRecord.t) Hashtbl.t

  let create () : t = Hashtbl.create (module Int)
end

(* TODO: This records for each client the number of its most ercent request, plus if the request has been executed, the reusult for that request*)
module State = struct
  type t =
    { configuration : Configuration.SortedIPList.t
      (* TODO: make sure that the invariant holds for the index when updating config. *)
    ; replica_number : int (* This is the index into its IP in configuration *)
    ; view_number : int (* Initially 0 *)
    ; status : Status.t
    ; op_number : int (* Initially 0, the most recently recieved request *)
    ; log : int list (* op_number enties, recieved so far, in their assigned order *)
    ; commit_number : int (* The most recent commited op_number *)
    ; client_table : ClientTable.t
    ; last_client_id : int (* Last client that joined the network, not in paper *)
    }

  let get_primary s = s.view_number % Configuration.SortedIPList.length s.configuration
end

module Log = struct end

let drop_request () = ()
let resend_last_response _response = ()

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
  Utils.log_info (sprintf "Sent %d bytes" (B.length buf))
;;

let add_client (state : State.t) =
  let state = { state with last_client_id = state.last_client_id + 1 } in
  Hashtbl.add_exn
    state.client_table
    ~key:state.last_client_id
    ~data:{ last_request_id = 0; last_result = None };
  Utils.log_info (sprintf "Client %d joined" state.last_client_id);
  state
;;

(* let wait_for_prepare_ok ~ip ~prepare = () *)

let send_prepare ~sw ~env (state : State.t) client_msg =
  let ips = Configuration.SortedIPList.to_list state.configuration in
  let primary_i = State.get_primary state in
  let non_primary = List.filteri ips ~f:(fun i _ -> not (Int.equal i primary_i)) in
  let prepare =
    Message.Replica_message.Prepare
      { view_number = 0; message = client_msg; op_number = 0; commit_number = 0 }
  in
  let send_to_replica addr =
    let host, port = addr in
    let net = Eio.Stdenv.net env in
    let connection = Eio.Net.connect ~sw net (`Tcp (host, port)) in
    let req = Message.to_bytes (Message.Replica_message prepare) in
    Write.with_flow connection (fun to_server -> Write.bytes to_server req)
  in
  Eio.Fiber.all (List.map ~f:(fun addr _ -> send_to_replica addr) non_primary)
;;

let handle_request (state : State.t) (r : Message.Client_request.t) =
  Utils.log_info "handle_request";
  if Operation.compare r.operation Join = 0
  then (
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
;;

let init_state ~addresses ~replica_address : State.t =
  let module IPs = Configuration.SortedIPList in
  let configuration = addresses in
  let replica_number = IPs.find_addr replica_address configuration |> Option.value_exn in
  { configuration
  ; replica_number
  ; view_number = 0
  ; status = Status.Normal
  ; op_number = 0
  ; log = []
  ; commit_number = 0
  ; client_table = ClientTable.create ()
  ; last_client_id = 0
  }
;;

let parse_request connection =
  let reader_request = [%bin_reader: Message.Client_request.t] in
  Bin_prot.Utils.bin_read_stream reader_request ~read:(fun buf ~pos ~len ->
    let c = Cstruct.create len in
    Eio.Flow.read_exact connection c;
    Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
;;

let handle_request state connection =
  let request = parse_request connection in
  Logs.info (fun f ->
    f "Payload: %s" (Sexp.to_string_hum @@ Message.Client_request.sexp_of_t request));
  (* state *)
  match handle_request state request with
  | None -> state
  | Some resp ->
    send_message (Message.Client_response resp) connection;
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
        try handle_request state connection |> continue with
        | End_of_file | Core_unix.Unix_error _ -> Utils.log_info "Closed | Unix_error"
      in
      continue state)
  done
;;

let start addresses replica_address =
  Utils.setup_log ();
  Utils.log_info_sexp
    [%message
      ""
        (sprintf
           !"Starting replica on %{sexp:Configuration.SortedIPList.addr}"
           replica_address)];
  Eio_main.run (fun env ->
    Eio.Switch.run (fun sw -> run_replica ~env ~sw addresses replica_address))
;;

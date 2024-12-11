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
    ; replica_number : int (* This is the index into its IP in configuration *)
    ; view_number : int (* Initially 0 *)
    ; status : Status.t
    ; op_number : int (* Initially 0, the most recently recieved request *)
    ; log : int list (* op_number enties, recieved so far, in their assigned order *)
    ; commit_number : int (* The most recent commited op_number *)
    ; client_table : ClientTable.t
    ; last_client_id : int (* Last client that joined the network, not in paper *)
    }
end

module Log = struct end

let drop_request () = ()
let resend_last_response _response = ()

let create_response (state : State.t) (req : Client_protocol.Request.t) =
  match req.operation with
  | Join -> Client_protocol.Response.Join { client_id = state.last_client_id }
  | Add _ -> Client_protocol.Response.Add { done_todo = true }
  | Update _ -> assert false
  | Remove _ -> assert false
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

let handle_request (state : State.t) (r : Client_protocol.Request.t) =
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

let init_state ~host ~port : State.t =
  let module IPs = Configuration.SortedIPList in
  let addr = IPs.parse_addr_exn (String.concat [ host; ":"; string_of_int port ]) in
  let configuration = IPs.add addr IPs.empty in
  let replica_number = IPs.find_addr addr configuration |> Option.value_exn in
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

let send_response resp connection =
  let writer_response = [%bin_writer: Client_protocol.Response.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_response resp in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  Write.with_flow connection (fun to_server -> Write.bytes to_server buf);
  Utils.log_info (sprintf "Sent %d bytes" (B.length buf))
;;

let handle_request state connection =
  let request =
    let reader_request = [%bin_reader: Client_protocol.Request.t] in
    Bin_prot.Utils.bin_read_stream reader_request ~read:(fun buf ~pos ~len ->
      let c = Cstruct.create len in
      Eio.Flow.read_exact connection c;
      Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
  in
  Logs.info (fun f ->
    f "Payload: %s" (Sexp.to_string_hum @@ Client_protocol.Request.sexp_of_t request));
  match handle_request state request with
  | None -> state
  | Some resp ->
    send_response resp connection;
    state
;;

let on_error e =
  Logs.err (fun f -> f "%s\n%s" (Exn.to_string e) (Printexc.get_backtrace ()))
;;

let run_server ~env ~sw ~host ~port =
  let state = ref @@ init_state ~host:(Fmt.str "%a" Eio.Net.Ipaddr.pp host) ~port in
  let net = Eio.Stdenv.net env in
  let socket =
    Eio.Net.listen ~reuse_addr:true ~sw net (`Tcp (host, port)) ~backlog:1024
  in
  while true do
    Eio.Net.accept_fork ~sw ~on_error socket (fun connection _ ->
      let rec continue () =
        try
          state := handle_request !state connection;
          continue ()
        with
        | End_of_file | Core_unix.Unix_error _ -> Utils.log_info "Closed | Unix_error"
      in
      continue ())
  done
;;

let setup_log () =
  (* Logs_threaded.enable (); *)
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let start () =
  Eio_main.run (fun env ->
    setup_log ();
    Logs.info (fun f -> f "Start Replica..");
    Eio.Switch.run (fun sw ->
      let host = Eio.Net.Ipaddr.V4.loopback in
      run_server ~env ~sw ~host ~port:8000))
;;

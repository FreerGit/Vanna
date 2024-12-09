module B = Bytes
module Write = Eio.Buf_write
open! Core
open! Vanna

let init_state ~host ~port : Vsr.State.t =
  let module IPs = Configuration.SortedIPList in
  let addr = IPs.parse_addr_exn (String.concat [ host; ":"; string_of_int port ]) in
  let configuration = IPs.add addr IPs.empty in
  let replica_number = IPs.find_addr addr configuration |> Option.value_exn in
  { configuration
  ; replica_number
  ; view_number = 0
  ; status = Vsr.Status.Normal
  ; op_number = 0
  ; log = []
  ; commit_number = 0
  ; client_table = Vsr.ClientTable.create ()
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
  match Vsr.handle_request state request with
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

let () =
  Eio_main.run (fun env ->
    setup_log ();
    Logs.info (fun f -> f "Start Replica..");
    Eio.Switch.run (fun sw ->
      let host = Eio.Net.Ipaddr.V4.loopback in
      run_server ~env ~sw ~host ~port:8000))
;;

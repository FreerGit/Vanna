module B = Bytes
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

let handle_request state connection =
  let request =
    let reader_request = [%bin_reader: Proxy.Request.t] in
    Bin_prot.Utils.bin_read_stream reader_request ~read:(fun buf ~pos ~len ->
      let c = Cstruct.create len in
      Eio.Flow.read_exact connection c;
      Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
  in
  if Operation.compare request.operation Join = 0
  then Vsr.add_client state
  else (
    Logs.info (fun f ->
      f "Payload: %s" (Sexp.to_string_hum @@ Proxy.Request.sexp_of_t request));
    Vsr.validate_request state.client_table request;
    state)
;;

let run_server ~env ~sw ~host ~port =
  let state = init_state ~host:(Fmt.str "%a" Eio.Net.Ipaddr.pp host) ~port in
  let net = Eio.Stdenv.net env in
  let socket =
    Eio.Net.listen ~reuse_addr:true ~sw net (`Tcp (host, port)) ~backlog:1024
  in
  let rec server_loop state =
    let connection = Eio.Net.accept ~sw socket in
    Eio.Fiber.fork ~sw (fun () ->
      let connection, _ = connection in
      let state' = handle_request state connection in
      server_loop state')
  in
  server_loop state
;;

let setup_log () =
  (* Logs_threaded.enable (); *)
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let () =
  try
    Eio_main.run (fun env ->
      setup_log ();
      Logs.info (fun f -> f "Start Replica..");
      Eio.Switch.run (fun sw ->
        let host = Eio.Net.Ipaddr.V4.loopback in
        run_server ~env ~sw ~host ~port:8000))
  with
  | exn -> Logs.err (fun f -> f "%s\n%s" (Exn.to_string exn) (Printexc.get_backtrace ()))
;;

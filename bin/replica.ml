module B = Bytes
open! Core
open! Vanna

let read_message connection =
  let request =
    let reader_request = [%bin_reader: Proxy.Request.t] in
    Bin_prot.Utils.bin_read_stream reader_request ~read:(fun buf ~pos ~len ->
      let c = Cstruct.create len in
      Eio.Flow.read_exact connection c;
      Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
  in
  Logs.info (fun f ->
    f "Payload: %s" (Sexp.to_string_hum @@ Proxy.Request.sexp_of_t request))
;;

let handle_connection connection =
  let r, _ = connection in
  try read_message r (* done *) with
  | End_of_file -> Logs.info (fun f -> f "Client disconnected")
  | exn -> Logs.err (fun f -> f "%s" (Exn.to_string exn))
;;

let run_server ~env ~sw ~host ~port =
  let net = Eio.Stdenv.net env in
  let socket =
    Eio.Net.listen ~reuse_addr:true ~sw net (`Tcp (host, port)) ~backlog:1024
  in
  while true do
    let connection = Eio.Net.accept ~sw socket in
    Eio.Fiber.fork ~sw (fun () -> handle_connection connection)
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

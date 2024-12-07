module B = Bytes
module Write = Eio.Buf_write
open! Core

(* open Eio.Std *)
open Vanna

let build_request req =
  let writer_msg = [%bin_writer: Proxy.Request.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_msg req in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  buf
;;

let run_client ~env ~sw ~host ~port =
  let net = Eio.Stdenv.net env in
  let flow = Eio.Net.connect ~sw net (`Tcp (host, port)) in
  let join_network_request : Proxy.Request.t =
    { op_number = 0; client_id = 0; request_number = 0; operation = Join }
  in
  let request = build_request join_network_request in
  Write.with_flow flow (fun to_server -> Write.bytes to_server request)
;;

let setup_log () =
  Logs_threaded.enable ();
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let () =
  setup_log ();
  Logs.info (fun f -> f "Start Client..");
  Eio_main.run (fun env ->
    Eio.Switch.run (fun sw ->
      let host = Eio.Net.Ipaddr.V4.loopback in
      let port = 8000 in
      run_client ~env ~sw ~host ~port))
;;

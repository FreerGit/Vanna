module B = Bytes
module Write = Eio.Buf_write
open! Core

(* open Eio.Std *)
open Vanna

let build_request req =
  let writer_msg = [%bin_writer: Client_protocol.Request.t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_msg req in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  buf
;;

let run_client ~env ~sw ~host ~port =
  let net = Eio.Stdenv.net env in
  let connection = Eio.Net.connect ~sw net (`Tcp (host, port)) in
  let join_network_request : Client_protocol.Request.t =
    { op_number = 0; client_id = 0; request_number = 2; operation = Join }
  in
  let request = build_request join_network_request in
  Write.with_flow connection (fun to_server -> Write.bytes to_server request);
  let response =
    let reader_response = [%bin_reader: Client_protocol.Response.t] in
    Bin_prot.Utils.bin_read_stream reader_response ~read:(fun buf ~pos ~len ->
      let c = Cstruct.create len in
      Eio.Flow.read_exact connection c;
      Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
  in
  Logs.info (fun f ->
    f "Payload: %s" (Sexp.to_string_hum @@ Client_protocol.Response.sexp_of_t response))
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

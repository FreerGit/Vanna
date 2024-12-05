module B = Bytes
module Write = Eio.Buf_write
open! Core

(* open Eio.Std *)
open Vanna

(* let send_request req =
   let writer = [%bin_writer: Client.Request.t] in
   let msg =Bin_prot.Writer.to_bytes writer req in
   B.length msg |> prepend the length of the message to msg
   ;; *)

(* Prepend the message length, replica has to know the message size. *)
let prepare_request req =
  (* let writer_msg = [%bin_writer: Proxy.Request.t] in
     let msg = Bin_prot.Writer.to_bytes writer_msg req in
     print_endline (B.to_string msg);
     Printf.printf "%d\n" (B.length msg);
     let writer_len = [%bin_writer: int] in
     let msg_len = Bin_prot.Writer.to_bytes writer_len (B.length msg) in
     print_endline (B.to_string msg_len);
     Printf.printf "%d\n" (B.length msg_len);
     B.cat msg_len msg *)
  let writer_msg = [%bin_writer: Proxy.Request.t] in
  let msg = Bin_prot.Writer.to_bytes writer_msg req in
  msg
;;

let run_client ~env ~sw ~host ~port =
  let net = Eio.Stdenv.net env in
  let flow = Eio.Net.connect ~sw net (`Tcp (host, port)) in
  let req : Proxy.Request.t =
    { op_number = 0; client_id = 2; request_number = 0; operation = Remove { key = "k" } }
  in
  let msg = prepare_request req in
  Write.with_flow flow
  @@ fun to_server ->
  Write.bytes to_server msg;
  ()
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

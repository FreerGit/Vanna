module B = Bytes
open! Core
open Eio.Std
(* open Vanna *)

let read_exactly connection buffer len =
  let rec aux offset remaining =
    if remaining = 0
    then ()
    else (
      let read_now = Eio.Flow.single_read connection buffer in
      Logs.info (fun f -> f "%s\n" (Cstruct.to_string buffer));
      aux (offset + read_now) (remaining - read_now))
  in
  aux 0 len
;;

let read_message connection =
  let header = Cstruct.create 4 in
  read_exactly connection header 4;
  let payload_size = Int32.to_int_exn (Cstruct.BE.get_uint32 header 0) in
  (* let payload = B.create payload_size in *)
  Logs.info (fun f -> f "Bytes: %s, num: %d\n" (Cstruct.to_string header) payload_size)
;;

(* read_exactly connection payload payload_size;
   (* TODO sum type *)
   let reader = [%bin_reader: Proxy.State.t] in
   Bin_prot.Reader.of_bytes reader payload *)

(* let handle_connection connection =
  let r, _ = connection in
  try
    while true do
      read_message r
      (* let message = read_message r in
         Logs.info (fun f ->
         f
         "Received: view_num=%d, request_num=%d, configuration=%s"
         message.view_num
         message.request_num
         (String.concat ~sep:", " message.configuration)) *)
      (* let response = { configuration = [ "OK" ]; view_num = 0; request_num = 0 } in
      send_message connection response *)
    done
  with
  | End_of_file -> Logs.info (fun f -> f "Client disconnected")
;; *)

let handle_connection connection =
  let r, _ = connection in
  try
    (* while true do *)
    Logs.info (fun f -> f "Reading message...");
    read_message r (* done *)
  with
  | End_of_file -> Logs.info (fun f -> f "Client disconnected")
  | exn -> Logs.err (fun f -> f "%s" (Exn.to_string exn))
;;

(* TCP server to handle incoming connections *)
let run_server ~env ~sw ~host ~port =
  (* Logs.info (fun f -> f "Starting server on %s:%d" (Ipaddr.V4.to_string host) port); *)
  let net = Eio.Stdenv.net env in
  let socket = Eio.Net.listen ~sw net (`Tcp (host, port)) ~backlog:1024 in
  while true do
    Switch.run
    @@ fun conn_sw ->
    let connection = Eio.Net.accept ~sw:conn_sw socket in
    Fiber.fork ~sw (fun () -> handle_connection connection)
  done
;;

let setup_log () =
  Logs_threaded.enable ();
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let () =
  Eio_main.run (fun env ->
    setup_log ();
    Switch.run (fun sw ->
      let host = Eio.Net.Ipaddr.V4.loopback in
      run_server ~env ~sw ~host ~port:8006))
;;

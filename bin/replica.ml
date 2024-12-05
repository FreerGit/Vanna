module B = Bytes
open! Core
open! Vanna

(* let read_exactly connection buffer len =
   let rec aux offset remaining =
   if remaining = 0
   then ()
   else (
   let read_now = Eio.Flow.single_read connection buffer in
   Logs.info (fun f -> f "%s\n" (Cstruct.to_string buffer));
   aux (offset + read_now) (remaining - read_now))
   in
   aux 0 len
   ;; *)

let read_message connection =
  (* let header = Cstruct.create 4 in *)
  (* read_exactly connection header 4; *)
  (* print_endline @@ Cstruct.to_string header; *)
  (* Get message lenght *)
  (* let reader_len = [%bin_reader: int] in *)
  (* let msg_len = Bin_prot.Reader.of_bytes reader_len (Cstruct.to_bytes header) in *)
  let buf = Cstruct.create 100 in
  (* read_exactly connection buf 5; *)
  let read_now = Eio.Flow.single_read connection buf in
  let reader_request = [%bin_reader: Proxy.Request.t] in
  let request =
    Bin_prot.Reader.of_bytes reader_request (Cstruct.to_bytes ~len:read_now buf)
  in
  Logs.info (fun f ->
    f
      "Payload size: %s\n Payload: \n"
      (Sexp.to_string_hum @@ Proxy.Request.sexp_of_t request))
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
  let socket =
    Eio.Net.listen ~reuse_addr:true ~sw net (`Tcp (host, port)) ~backlog:1024
  in
  while true do
    Eio.Switch.run
    @@ fun conn_sw ->
    let connection = Eio.Net.accept ~sw:conn_sw socket in
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

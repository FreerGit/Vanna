module B = Bytes
module Write = Eio.Buf_write
open! Core

module State = struct
  type t =
    { client_id : int
    ; request_number : int
    }
end

let read_response connection =
  let reader_response = [%bin_reader: Message.Client_response.t] in
  Bin_prot.Utils.bin_read_stream reader_response ~read:(fun buf ~pos ~len ->
    let c = Cstruct.create len in
    Eio.Flow.read_exact connection c;
    Bin_prot.Common.blit_bytes_buf ~src_pos:pos (Cstruct.to_bytes c) buf ~len)
;;

(* TODO client state *)
let run_client ~f ~env ~sw ~addr =
  let net = Eio.Stdenv.net env in
  let connection = Eio.Net.connect ~sw net (`Tcp addr) in
  let continue = ref true in
  let state = ref State.{ client_id = 0; request_number = 0 } in
  while !continue do
    let command = f !state in
    (* state := state'; *)
    match command with
    | None -> continue := false
    | Some r ->
      let req = Message.to_bytes r in
      Write.with_flow connection (fun to_server -> Write.bytes to_server req);
      let resp = read_response connection in
      (match resp with
       | Join x ->
         state := { client_id = x.client_id; request_number = !state.request_number + 1 }
       | Add _ -> ()
       | Outdated -> ());
      Logs.info (fun f ->
        f "Payload: %s" (Sexp.to_string_hum @@ Message.Client_response.sexp_of_t resp))
  done
;;

(* let join_network_request : Client_protocol.Request.t =
    { client_id = 0; request_number = 0; operation = Join }
  in *)
(* let request = build_request join_network_request in *)
(* Write.with_flow connection (fun to_server -> Write.bytes to_server request); *)
(* let join_resp = read_response connection in
  Logs.info (fun f ->
    f "Payload: %s" (Sexp.to_string_hum @@ Client_protocol.Response.sexp_of_t join_resp));
  match join_resp with
  | Join { client_id } ->
    let add_request : Client_protocol.Request.t =
      { client_id; request_number = 1; operation = Add { key = "first"; value = "1" } }
    in
    let request = build_request add_request in
    Write.with_flow connection (fun to_server -> Write.bytes to_server request);
    Utils.log_info "here";
    let response = read_response connection in
    Utils.log_info "here";
    Logs.info (fun f ->
      f "Payload: %s" (Sexp.to_string_hum @@ Client_protocol.Response.sexp_of_t response))
  | _ -> raise_s [%message "idk"] *)

let setup_log () =
  Logs_threaded.enable ();
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let start ~addr ~f =
  setup_log ();
  Logs.info (fun f -> f "Start Client..");
  Eio_main.run (fun env -> Eio.Switch.run (fun sw -> run_client ~f ~env ~sw ~addr))
;;

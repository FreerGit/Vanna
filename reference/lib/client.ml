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
  let reader_response = [%bin_reader: Message.Reply.t] in
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
      (match resp.result with
       | JoinResult (Ok x) ->
         state := { client_id = x; request_number = !state.request_number + 1 }
       | AddResult (Ok _) -> ()
       | Outdated -> ()
       | _ -> raise_s [%message "TODO" ~here:[%here]]);
      Logs.info (fun f ->
        f "Payload: %s" (Sexp.to_string_hum @@ Message.Reply.sexp_of_t resp))
  done
;;

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

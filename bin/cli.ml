open! Core
open Vanna

let parse_command input =
  try
    match Sexp.of_string input with
    | sexp -> Ok (Client_protocol.Request.t_of_sexp sexp)
  with
  | exn -> Error (Exn.to_string exn)
;;

let start_client_with_stdin () =
  let _ = Domain.spawn (fun () -> Client.start ()) in
  Eio_main.run (fun env ->
    let stdin = Eio.Stdenv.stdin env in
    let rec loop () =
      Utils.log_info "Enter new Request.t";
      let input = Eio.Flow.read_all stdin in
      match parse_command input with
      | Ok command ->
        Utils.log_info
          (sprintf
             "Parsed command: %s\n"
             (Sexp.to_string (Client_protocol.Request.sexp_of_t command)));
        loop ()
      | Error msg ->
        eprintf "Error parsing command: %s\n" msg;
        loop ()
    in
    loop ())
;;

let commands =
  Command.group
    ~summary:"Client or Replica node"
    [ ( "run-client"
      , Command.basic
          ~summary:"Run a client"
          (let%map_open.Command () = return () in
           fun () -> start_client_with_stdin ()) )
    ; ( "run-replica"
      , Command.basic
          ~summary:"Run a replica"
          (let%map_open.Command () = return () in
           fun () -> Replica.start ()) )
    ]
;;

let () = Command_unix.run commands
(* Command.Param.map *)

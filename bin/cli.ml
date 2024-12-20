open! Core
open Vanna

(* let join_command =
  Command.basic
    ~summary:"Join the cluster"
    (Command.Param.return (fun () ->
       request := { client_id = 0; request_number = 0; operation = Join }))
;;

let add_command =
  Command.basic
    ~summary:"Add a key-value pair"
    (let%map_open.Command key = flag "key" (required string) ~doc:"string Key"
     and value = flag "value" (required string) ~doc:"string Value" in
     fun () ->
       request := { client_id = 1; request_number = 1; operation = Add { key; value } })
;; *)

let parse_command input (state : Client.State.t) : Message.Client_request.t option =
  let command : Message.Client_request.t =
    { client_id = state.client_id
    ; request_number = state.request_number
    ; operation = Join
    }
  in
  match String.split ~on:' ' input with
  | [ "Join" ] -> Some { command with operation = Join }
  | [ "Add"; key; value ] -> Some { command with operation = Add { key; value } }
  | [ "Update"; key; value ] -> Some { command with operation = Update { key; value } }
  | [ "Remove"; key ] -> Some { command with operation = Remove { key } }
  | _ -> None
;;

let get_command (state : Client.State.t) =
  printf "> ";
  Out_channel.flush stdout;
  match In_channel.input_line In_channel.stdin with
  | None -> None (* End of input (Ctrl+D) *)
  | Some input -> parse_command input state
;;

let start_client_with_stdin () =
  Client.start ~f:(fun state ->
    Utils.log_info "Client started. Enter commands:\n";
    get_command state)
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

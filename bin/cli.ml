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

let parse_command input (state : Client.State.t) : Message.t option =
  let command : Message.Client_request.t =
    { client_id = state.client_id
    ; request_number = state.request_number
    ; operation = Join
    }
  in
  match String.split ~on:' ' input with
  | [ "Join" ] -> Some (Message.Client_request { command with operation = Join })
  | [ "Add"; key; value ] ->
    let key, value = Bytes.of_string key, Bytes.of_string value in
    Some (Message.Client_request { command with operation = Add { key; value } })
  | [ "Update"; key; value ] ->
    let key, value = Bytes.of_string key, Bytes.of_string value in
    Some (Message.Client_request { command with operation = Update { key; value } })
  | [ "Remove"; key ] ->
    let key = Bytes.of_string key in
    Some (Message.Client_request { command with operation = Remove { key } })
  | _ -> None
;;

let get_command (state : Client.State.t) =
  printf "> ";
  Out_channel.flush stdout;
  match In_channel.input_line In_channel.stdin with
  | None -> None (* End of input (Ctrl+D) *)
  | Some input -> parse_command input state
;;

let start_client_with_stdin addr =
  Client.start ~addr ~f:(fun state ->
    Utils.log_info "Client started. Enter commands:\n";
    get_command state)
;;

let get_ip_list s =
  let open Configuration in
  let addrs = String.split_on_chars s ~on:[ ',' ] in
  List.fold addrs ~init:empty ~f:(fun acc addr -> add (parse_addr_exn addr) acc)
;;

let get_replica_addr s replica =
  let addrs = String.split_on_chars s ~on:[ ',' ] in
  match List.nth addrs replica with
  | None ->
    raise_s [%message "Replica index is out of range (addresses list)" ~here:[%here]]
  | Some addr -> Vanna.Configuration.parse_addr_exn addr
;;

let commands =
  Command.group
    ~summary:"Client or Replica node"
    [ ( "run-client"
      , Command.basic
          ~summary:"Run a client"
          (let%map_open.Command primary =
             flag "primary" (required string) ~doc:"string Address to primary"
           in
           fun () ->
             let addr = Vanna.Configuration.parse_addr_exn primary in
             start_client_with_stdin addr) )
    ; ( "run-replica"
      , Command.basic
          ~summary:"Run a replica"
          (let%map_open.Command addresses =
             flag "addresses" (required string) ~doc:"string All Adresses"
           and replica =
             flag "replica" (required int) ~doc:"int This replicas index into addresses"
           in
           fun () ->
             let replica_address = get_replica_addr addresses replica in
             let addresses = get_ip_list addresses in
             Replica.start addresses replica_address) )
    ]
;;

let () = Command_unix.run commands

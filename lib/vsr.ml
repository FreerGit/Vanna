open! Core

module Status = struct
  type t =
    | Normal
    | ViewChange
    | Recovering
  [@@deriving bin_io, sexp]
end

module ClientTable = struct
  module RequstRecord = struct
    type t =
      { last_request_id : int
      ; last_result : int option (* None implies not executed*)
      }
    [@@deriving sexp, hash, compare]
  end

  type t = (int, RequstRecord.t) Hashtbl.t

  let create () : t = Hashtbl.create (module Int)
end

(* TODO: This records for each client the number of its most ercent request, plus if the request has been executed, the reusult for that request*)
module State = struct
  type t =
    { configuration : Configuration.SortedIPList.t
    ; replica_number : int (* This is the index into its IP in configuration *)
    ; view_number : int (* Initially 0 *)
    ; status : Status.t
    ; op_number : int (* Initially 0, the most recently recieved request *)
    ; log : int list (* op_number enties, recieved so far, in their assigned order *)
    ; commit_number : int (* The most recent commited op_number *)
    ; client_table : ClientTable.t
    ; last_client_id : int (* Last client that joined the network, not in paper *)
    }
end

module Log = struct end

let drop_request () = ()
let resend_last_response _response = ()

let create_response (state : State.t) (req : Client_protocol.Request.t) =
  match req.operation with
  | Join -> Client_protocol.Response.Join { client_id = state.last_client_id }
  | Add _ -> assert false
  | Update _ -> assert false
  | Remove _ -> assert false
;;

let add_client (state : State.t) =
  let state' = { state with last_client_id = state.last_client_id + 1 } in
  Utils.log_info (sprintf "Client %d joined" state'.last_client_id);
  state'
;;

let handle_request (state : State.t) (r : Client_protocol.Request.t) =
  if Operation.compare r.operation Join = 0
  then (
    let state = add_client state in
    Some (create_response state r))
  else (
    match Hashtbl.find state.client_table r.client_id with
    | None -> raise_s [%message (sprintf "client %d not in table" r.client_id) [%here]]
    | Some v ->
      Utils.log_info
        (sprintf "%d %d" (compare r.request_number v.last_request_id) r.request_number);
      (match compare r.request_number v.last_request_id with
       | x when x < 0 ->
         drop_request ();
         None
       | 0 ->
         drop_request ();
         (match v.last_result with
          | None -> ()
          | Some r -> resend_last_response r);
         None
       | _ -> Some (create_response state r)))
;;

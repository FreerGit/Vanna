open! Core

module Status = struct
  type t =
    | Normal
    | ViewChange
    | Recovering
  [@@deriving bin_io, sexp]
end

module State = struct
  type t =
    { configuration : Configuration.SortedIPList.t
    ; replica_number : int (* This is the index into its IP in configuration *)
    ; view_number : int (* Initially 0 *)
    ; status : Status.t
    ; op_number : int (* Initially 0, the most recently recieved request *)
    ; log : int list (* op_number enties, recieved so far, in their assigned order *)
    ; commit_number : int (* The most recent commited op_number *)
    ; client_table : unit
    (* TODO: This records for each client the number of its most ercent request, plus if the request has been executed, the reusult for that request*)
    }
end

let drop_request () = ()
let resend_last_response _response = ()
let handle_request () = ()

let validate_request (client_table : Proxy.ClientTable.t) (request : Proxy.Request.t) =
  match Hashtbl.find client_table request.client_id with
  | None -> raise_s [%message "client %d not in table" (request.client_id : int) [%here]]
  | Some v ->
    (match compare request.request_number v.last_request with
     | x when x < 0 -> drop_request ()
     | 0 ->
       drop_request ();
       (match v.last_result with
        | None -> ()
        | Some r -> resend_last_response r)
     | _ -> handle_request ())
;;

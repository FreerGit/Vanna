open! Core

module Client_request = struct
  type t =
    { client_id : int
    ; request_number : int
    ; operation : Operation.t
    }
  [@@deriving bin_io, sexp]
end

module Client_response = struct
  type t =
    | Join of { client_id : int }
    | Add of { done_todo : bool }
  [@@deriving bin_io, sexp, compare]
end

module Replica_message = struct
  type t =
    | Preapre of
        { view_number : int
        ; message : Client_request.t
        ; op_number : int
        ; commit_number : int
        }
    | PrepareOk of
        { view_number : int
        ; op_number : int
        ; client_id : int
        }
  [@@deriving bin_io, sexp]
end
(* | Reply of { view_number: int; } *)

module Message = struct
  type t =
    | Client_request of Client_request.t
    | Replica_message of Replica_message.t
  [@@deriving bin_io, sexp]
end

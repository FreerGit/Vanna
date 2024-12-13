open! Core

module Request = struct
  type t =
    { client_id : int
    ; request_number : int
    ; operation : Operation.t
    }
  [@@deriving bin_io, sexp]
end

module Response = struct
  type t =
    | Join of { client_id : int }
    | Add of { done_todo : bool }
  [@@deriving bin_io, sexp, compare]
end

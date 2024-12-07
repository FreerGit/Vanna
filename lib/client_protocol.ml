open! Core

module Request = struct
  type t =
    { op_number : int
    ; client_id : int
    ; request_number : int
    ; operation : Operation.t
    }
  [@@deriving bin_io, sexp]
end

module Response = struct
  type t = Join of { client_id : int } [@@deriving bin_io, sexp]
end

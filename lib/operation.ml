open! Core

type t =
  | Add of
      { key : Bytes.t
      ; value : Bytes.t
      }
  | Update of
      { key : Bytes.t
      ; value : Bytes.t
      }
  | Remove of { key : Bytes.t }
  | Join
[@@deriving bin_io, sexp, compare]

type result =
  | AddResult of (unit, unit) Result.t (* TODO: error type *)
  | UpdateResult of (unit, unit) Result.t (* TODO: error type *)
  | RemoveResult of (unit, unit) Result.t (* TODO: error type *)
  | JoinResult of (int, unit) Result.t (* TODO: error type *)
  | Outdated
[@@deriving bin_io, sexp, compare]

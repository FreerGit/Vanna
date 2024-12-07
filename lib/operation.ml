open! Core

type t =
  | Add of
      { key : string
      ; value : string
      }
  | Update of
      { key : string
      ; value : string
      }
  | Remove of { key : string }
  | Join
[@@deriving bin_io, sexp, compare]

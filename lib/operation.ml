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

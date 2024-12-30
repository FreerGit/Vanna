open! Core
module B = Bytes

module Request = struct
  type t =
    { client_id : int
    ; request_number : int
    ; op : Operation.t
    }
  [@@deriving bin_io, sexp, compare]
end

module Reply = struct
  type t =
    { view_number : int
    ; request_number : int
    ; result : Operation.result
    }
  [@@deriving bin_io, sexp, compare]
end

module Replica = struct
  type t =
    | Prepare of
        { view_number : int
        ; message : Request.t
        ; op_number : int
        ; commit_number : int
        }
    | PrepareOk of
        { view_number : int
        ; op_number : int
        ; replica_number : int
        }
  [@@deriving bin_io, sexp, compare]
end
(* | Reply of { view_number: int; } *)

type t =
  | Client_request of Request.t
  | Replica_message of Replica.t
[@@deriving bin_io, sexp]

let to_bytes req =
  let writer_msg = [%bin_writer: t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_msg req in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  buf
;;

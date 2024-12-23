open! Core
module B = Bytes

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
    | Outdated
  [@@deriving bin_io, sexp, compare]
end

module Replica_message = struct
  type t =
    | Prepare of
        { view_number : int
        ; message : Client_request.t
        ; op_number : int
        ; commit_number : int
        }
    | PrepareOk of
        { view_number : int
        ; op_number : int
        ; replica_number : int
        }
  [@@deriving bin_io, sexp]
end
(* | Reply of { view_number: int; } *)

type t =
  | Client_request of Client_request.t
  | Replica_message of Replica_message.t
[@@deriving bin_io, sexp]

let to_bytes req =
  let writer_msg = [%bin_writer: t] in
  let msg = Bin_prot.Utils.bin_dump ~header:true writer_msg req in
  let buf = B.create (Bin_prot.Common.buf_len msg) in
  Bin_prot.Common.blit_buf_bytes msg ~len:(B.length buf) buf;
  buf
;;

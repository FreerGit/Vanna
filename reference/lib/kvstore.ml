open! Core

module BytesKey = struct
  type t = Bytes.t [@@deriving compare, sexp]

  let hash = Hashtbl.hash
end

type t = (BytesKey.t, Bytes.t) Hashtbl.t [@@deriving sexp_of]

let create () : t = Hashtbl.create (module BytesKey)
let set store ~key ~value = Hashtbl.set store ~key ~data:value
let get store ~key = Hashtbl.find store key
let remove store ~key = Hashtbl.remove store key

type addr = Eio.Net.Ipaddr.v4v6 * int
type t [@@deriving sexp_of]

val sexp_of_addr : addr -> Sexplib0.Sexp.t
val empty : t

(* raises on failure *)
val parse_addr_exn : string -> addr
val add : addr -> t -> t

(* Has no effect if addr is not found *)
val remove : addr -> t -> t

(* Returns the index *)
val find_addr : addr -> t -> int option
val to_list : t -> addr list
val length : t -> int
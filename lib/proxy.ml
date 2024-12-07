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

(* let handle_client_request () : ClientTable.t = Hashtbl.create (module Int) *)

(* open Bin_prot.Std
open! Core

module State = struct
  type t =
    { configuration : Configuration.SortedIPList.t
    ; view_number : int
    ; request_number : int
    }
  [@@deriving sexp_of]
  (* [@@deriving bin_io] *)
end

let%expect_test "tt" =
  let x : State.t =
    { configuration = Configuration.SortedIPList.empty
    ; view_number = 0
    ; request_number = 0
    }
  in
  print_s (State.sexp_of_t x);
  [%expect {| ((configuration ()) (view_number 0) (request_number 0)) |}]
;;

let%test _ = 5 = 5 *)

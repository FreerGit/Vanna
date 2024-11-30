open Bin_prot.Std

(* TODO: add SortedIPv4List *)
module State = struct
  type t =
    { configuration : string list
    ; view_num : int
    ; request_num : int
    }
  [@@deriving bin_io]
end

let%expect_test "tt" =
  let abc = 338 in
  print_int abc;
  [%expect {| 338 |}]
;;

let%test _ = 5 = 5

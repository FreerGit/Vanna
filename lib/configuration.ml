open! Core

(* TODO: should dups be included? *)
module SortedIPList : sig
  module Inet_addr = Core_unix.Inet_addr

  type addr = Inet_addr.t * int [@@deriving sexp_of]
  type t [@@deriving sexp_of]

  val empty : t
  val add_exn : string -> t -> t
  val remove : addr -> t -> t
  val to_list : t -> addr list
end = struct
  module Inet_addr = Core_unix.Inet_addr

  type addr = Inet_addr.t * int [@@deriving sexp_of]
  type t = addr list [@@deriving sexp_of]

  let compare (ip1, port1) (ip2, port2) =
    let ip_cmp = Inet_addr.compare ip1 ip2 in
    if ip_cmp <> 0 then ip_cmp else Int.compare port1 port2
  ;;

  let insert_sorted lst new_entry =
    let rec insert = function
      | [] -> [ new_entry ]
      | hd :: tl as l ->
        if compare new_entry hd <= 0 then new_entry :: l else hd :: insert tl
    in
    insert lst
  ;;

  let empty = []

  let add_exn ip_str sorted =
    let f ip port =
      try
        match Inet_addr.of_string ip, Int.of_string_opt port with
        | ipaddr, port_num ->
          let new_entry = ipaddr, Option.value port_num ~default:80 in
          let sorted_list = insert_sorted sorted new_entry in
          sorted_list
      with
      | Failure s -> raise_s [%message "%s" (s : string) ~here:[%here]]
    in
    match String.split_on_chars ~on:[ ':' ] ip_str with
    | [ ip ] -> f ip "80"
    | [ ip; port ] -> f ip port
    | _ -> raise_s [%message "Malformed IP" ~here:[%here]]
  ;;

  let remove t sorted =
    let rec r = function
      | [] -> []
      | hd :: tl -> if compare t hd = 0 then tl else hd :: r tl
    in
    r sorted
  ;;

  let to_list t = t
end

let%expect_test "tt" =
  let open SortedIPList in
  let addresses =
    [ "10.0.0.1:4444"
    ; "10.0.0.1:80"
    ; "127.0.0.1"
    ; "10.0.0.1:80"
    ; "192.168.0.1:8080"
    ; "127.0.0.1:9090"
    ; "10.0.0.1"
    ]
  in
  let sorted_addresses =
    List.fold addresses ~init:empty ~f:(fun acc addr -> add_exn addr acc)
  in
  let third = List.nth_exn (to_list sorted_addresses) 2 in
  let sorted_addresses = remove third sorted_addresses in
  print_s (sexp_of_list SortedIPList.sexp_of_addr (to_list sorted_addresses));
  [%expect
    {|
    ((10.0.0.1 80) (10.0.0.1 80) (10.0.0.1 4444) (127.0.0.1 80) (127.0.0.1 9090)
     (192.168.0.1 8080))
    |}]
;;

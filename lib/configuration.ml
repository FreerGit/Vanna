open! Core

(* TODO: should dups be included? *)
module SortedIPList : sig
  module Inet_addr = Core_unix.Inet_addr

  type addr = Inet_addr.t * int [@@deriving sexp_of]
  type t [@@deriving sexp_of]

  val empty : t

  (* raises on failure *)
  val parse_addr_exn : string -> addr
  val add : addr -> t -> t

  (* Has no effect if addr is not found *)
  val remove : addr -> t -> t

  (* Returns the index *)
  val find_addr : addr -> t -> int option
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

  let parse_addr_exn ip_str =
    let f ip port =
      try
        match Inet_addr.of_string ip, Int.of_string_opt port with
        | ipaddr, port_num -> ipaddr, Option.value port_num ~default:80
      with
      | Failure s -> raise_s [%message "%s" (s : string) ~here:[%here]]
    in
    match String.split_on_chars ~on:[ ':' ] ip_str with
    | [ ip ] -> f ip "80"
    | [ ip; port ] -> f ip port
    | _ -> raise_s [%message "Malformed IP" ~here:[%here]]
  ;;

  let empty = []
  let add addr sorted = insert_sorted sorted addr

  let remove t sorted =
    let rec r = function
      | [] -> []
      | hd :: tl -> if compare t hd = 0 then tl else hd :: r tl
    in
    r sorted
  ;;

  let find_addr (addr : addr) (addrs : t) =
    List.foldi ~init:None addrs ~f:(fun i acc a ->
      if compare a addr = 0 then Some i else acc)
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
    List.fold addresses ~init:empty ~f:(fun acc addr -> add (parse_addr_exn addr) acc)
  in
  let third = List.nth_exn (to_list sorted_addresses) 2 in
  let sorted_addresses = remove third sorted_addresses in
  print_s (sexp_of_list SortedIPList.sexp_of_addr (to_list sorted_addresses));
  [%expect
    {|
    ((10.0.0.1 80) (10.0.0.1 80) (10.0.0.1 4444) (127.0.0.1 80) (127.0.0.1 9090)
     (192.168.0.1 8080))
    |}];
  let f ip =
    print_s
    @@ sexp_of_option sexp_of_int
    @@ find_addr (parse_addr_exn ip) sorted_addresses
  in
  f "127.0.0.1";
  f "127.0.0.1:9090";
  f "192.168.0.1:8080";
  f "192.168.0.1:5555";
  f "10.1.1.1:80";
  [%expect {|
    (3)
    (4)
    (5)
    ()
    ()
    |}]
;;
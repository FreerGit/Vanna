open! Core

type entry =
  { op_number : int
  ; req : Message.Request.t
  }
[@@deriving sexp]

type t =
  { entries : entry Deque.t
  ; mutable last_checkpointed : int (* op_number *)
  }
[@@deriving sexp]

let create_log ?initial_length () =
  { entries = Deque.create ?initial_length (); last_checkpointed = 0 }
;;

let append_entry t entry =
  let increasing () =
    Deque.peek_back_exn t.entries |> fun e -> e.op_number < entry.op_number
  in
  assert (Deque.is_empty t.entries || increasing ());
  Deque.enqueue_back t.entries entry
;;

(* let get_entry t op_number =
   if op_number <= t.last_checkpointed
   then None
   else Deque.find t.entries ~f:(fun e -> e.op_number = op_number)
   ;; *)

let get_log_entry t commit =
  Utils.assert_int [%here] ( > ) commit 0;
  Utils.assert_int [%here] ( > ) commit t.last_checkpointed;
  match Deque.find t.entries ~f:(fun e -> e.op_number = commit) with
  | None -> raise_s [%message "TODO" ~here:[%here]]
  | Some e ->
    t.last_checkpointed <- commit;
    e
;;

let%expect_test _ =
  Printexc.record_backtrace false;
  let key, value = Bytes.of_string "k", Bytes.of_string "v" in
  let log = create_log () in
  let req = Message.Request.{ client_id = 0; request_number = 0; op = Join } in
  append_entry log { op_number = 1; req = { req with op = Join } };
  append_entry log { op_number = 2; req = { req with op = Operation.Add { key; value } } };
  append_entry log { op_number = 3; req = { req with op = Operation.Remove { key } } };
  let pp e = sexp_of_entry e |> print_s in
  get_log_entry log 1 |> pp;
  get_log_entry log 2 |> pp;
  [%expect
    {|
    ((op_number 1) (req ((client_id 0) (request_number 0) (op Join))))
    ((op_number 2)
     (req ((client_id 0) (request_number 0) (op (Add (key k) (value v))))))
    |}]
;;
(* get_log_entry log 4 |> pp; *)

(* get_entry log 0 |> Option.sexp_of_t sexp_of_entry |> print_s; *)
(* [%expect {|  |}] *)

open! Core

type entry =
  { op_number : int
  ; op : Operation.t
  }

type t = entry Deque.t

let create_log ~initial_length () = Deque.create ~initial_length ()
let append_entry t entry = Deque.enqueue_back t entry

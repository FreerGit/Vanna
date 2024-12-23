open! Core

let setup_log () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level ~all:true (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let log_info msg = Logs.info (fun f -> f "%s" msg)

let log_info_sexp ?(msg = "") sexp =
  Logs.info (fun f -> f "%s" (msg ^ Sexp.to_string_hum sexp))
;;

let assert_with_sexp (condition : bool) (a : 'a) (b : 'a) (sexp_of_a : 'a -> Sexp.t) =
  if not condition
  then (
    let error_message =
      sprintf
        "lhs: %s rhs: %s"
        (Sexp.to_string_hum (sexp_of_a a))
        (Sexp.to_string_hum (sexp_of_a b))
    in
    failwith error_message)
;;

let assert_s op (a : 'a) (b : 'a) sexp_of = assert_with_sexp (op a b) a b sexp_of

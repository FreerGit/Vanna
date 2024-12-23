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

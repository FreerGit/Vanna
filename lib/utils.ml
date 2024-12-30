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

let assert_int here op a b =
  if op a b
  then ()
  else
    raise_s
      [%message
        "Assert failed"
          ~here:(Source_code_position.to_string here : string)
          ~details:(sprintf "Comparison failed: %d and %d" a b)]
;;

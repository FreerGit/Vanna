open! Core

let log_info msg = Logs.info (fun f -> f "%s" msg)
let log_info_sexp msg = Logs.info (fun f -> f "%s" (Sexp.to_string_hum msg))

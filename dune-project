(lang dune 3.16)

(name vanna)

(generate_opam_files true)

(source
 (github Freergit/vanna))

(authors "Sven")

(maintainers "Sven")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name vanna)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
  ocaml
  dune
  core
  core_unix
  yojson
  logs
  fmt
  bin_prot
  ppx_jane
  ppx_expect
  ppx_assert
  ppx_string
  ppx_here
  ppx_let
  ppx_custom_printf
  ppx_sexp_message
  ppx_yojson_conv
  ppx_bin_prot
  ppx_deriving
  eio
  eio_main
  piaf
  alcotest)
 (tags
  (topics "to describe" your project)))

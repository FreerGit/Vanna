module B = Bytes
module Write = Eio.Buf_write
open! Core
open Eio.Std

let run_client ~env ~sw ~host ~port =
  let net = Eio.Stdenv.net env in
  let flow = Eio.Net.connect ~sw net (`Tcp (host, port)) in
  Write.with_flow flow
  @@ fun to_server ->
  Write.bytes to_server (B.of_string "\x00\x00\x04\xd2");
  ()
;;

let () =
  Eio_main.run (fun env ->
    Switch.run (fun sw ->
      let host = Eio.Net.Ipaddr.V4.loopback in
      let port = 8000 in
      run_client ~env ~sw ~host ~port))
;;

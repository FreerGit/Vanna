open Alcotest

let add x y = x + y
let test_add () = (check int) "same int" 3 (add 1 2)
let () = run "DB suite" [ "addition", [ test_case "1 + 2 = 3" `Quick test_add ] ]

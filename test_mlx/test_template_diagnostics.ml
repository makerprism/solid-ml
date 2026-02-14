open Ppxlib

let contains_substring ~haystack ~needle =
  let hlen = String.length haystack in
  let nlen = String.length needle in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  if nlen = 0 then true else loop 0

let expect_diagnostic ~name ~source ~needle =
  let lexbuf = Lexing.from_string source in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = name };
  let structure = Ppxlib.Parse.implementation lexbuf in
  match
    try
      ignore (Solid_ml_template_ppx.impl structure);
      None
    with
    | exn -> Some (Printexc.to_string exn)
  with
  | None ->
    failwith
      ("Expected PPX diagnostic containing: " ^ needle ^ "\nBut transformation succeeded")
  | Some msg ->
    if not (contains_substring ~haystack:msg ~needle) then
      failwith
        ("Expected PPX diagnostic containing: "
        ^ needle
        ^ "\nActual:\n"
        ^ msg)

let () =
  let unsupported_child_msg =
    "unsupported JSX child function application in a dynamic template."
  in

  expect_diagnostic
    ~name:"reject_value_child.ml"
    ~source:
      {|
open Html

let _ =
  div
    ~onclick:(fun _ -> ())
    ~children:[ string_of_int 1 ]
    ()
|}
    ~needle:unsupported_child_msg;

  expect_diagnostic
    ~name:"reject_unit_then_value.ml"
    ~source:
      {|
open Html

let helper () x =
  text (string_of_int x)

let _ =
  div
    ~onclick:(fun _ -> ())
    ~children:[ helper () 1 ]
    ()
|}
    ~needle:unsupported_child_msg;

  print_endline "  PASSED"

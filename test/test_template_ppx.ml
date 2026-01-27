open Ppxlib

let parse_structure ~filename code : Parsetree.structure =
  let lexbuf = Lexing.from_string code in
  Location.init lexbuf filename;
  Parse.implementation lexbuf

let assert_some name = function
  | None -> failwith (name ^ ": expected Some")
  | Some _ -> ()

let assert_none name = function
  | None -> ()
  | Some _ -> failwith (name ^ ": expected None")

let string_contains_substring ~haystack ~needle =
  let haystack_len = String.length haystack in
  let needle_len = String.length needle in
  if needle_len = 0 then true
  else if needle_len > haystack_len then false
  else
    let rec check_pos pos =
      if pos > haystack_len - needle_len then false
      else
        let rec check_offset offset =
          if offset = needle_len then true
          else if haystack.[pos + offset] = needle.[offset]
          then check_offset (offset + 1)
          else false
        in
        if check_offset 0 then true else check_pos (pos + 1)
    in
    check_pos 0

let () =
  print_endline "=== Template PPX Diagnostics Tests ===";

  (* The PPX should detect direct marker calls. *)
  let s1 = parse_structure ~filename:"case1.ml" "let _ = Tpl.text (fun () -> \"hi\")" in
  assert_some "detect direct Tpl.text" (Solid_ml_template_ppx.contains_tpl_markers s1);

  (* It should also detect simple module aliases to the runtime Tpl module. *)
  let s2 =
    parse_structure ~filename:"case2.ml"
      "module T = Solid_ml_template_runtime.Tpl\nlet _ = T.text (fun () -> \"hi\")"
  in
  assert_some "detect alias T.text" (Solid_ml_template_ppx.contains_tpl_markers s2);

  (* And close over a shallow alias chain. *)
  let s2b =
    parse_structure ~filename:"case2b.ml"
      "module T = Solid_ml_template_runtime.Tpl\nmodule U = T\nlet _ = U.text (fun () -> \"hi\")"
  in
  assert_some "detect alias chain U.text" (Solid_ml_template_ppx.contains_tpl_markers s2b);

  (* Also allow aliasing the unqualified Tpl module when in scope. *)
  let s2c =
    parse_structure ~filename:"case2c.ml"
      "open Solid_ml_template_runtime\nmodule V = Tpl\nlet _ = V.text (fun () -> \"hi\")"
  in
  assert_some "detect open+alias V.text" (Solid_ml_template_ppx.contains_tpl_markers s2c);

  (* Bare identifiers are not considered a marker *use*. *)
  let s3 = parse_structure ~filename:"case3.ml" "let _ = Tpl.text" in
  assert_none "ignore bare Tpl.text ident" (Solid_ml_template_ppx.contains_tpl_markers s3);

  let s4 =
    parse_structure ~filename:"case4.ml"
      "open Solid_ml_template_runtime\n\
       let _ =\n\
         Html.div ~children:[\n\
           Tpl.show_when ~when_:(fun () -> true) (fun () -> Html.text \"a\");\n\
           Tpl.show_when ~when_:(fun () -> false) (fun () -> Html.text \"b\");\n\
         ] ()"
  in
  let warnings = ref [] in
  let prev = !(Solid_ml_template_ppx.warning_hook) in
  Solid_ml_template_ppx.warning_hook := Some (fun _loc msg ->
    warnings := msg :: !warnings;
    true);
  (match Solid_ml_template_ppx.transform_structure s4 with _ -> ());
  Solid_ml_template_ppx.warning_hook := prev;
  let has_sibling_warning =
    List.exists
      (fun msg ->
        string_contains_substring
          ~haystack:(String.lowercase_ascii msg)
          ~needle:"sibling conditional")
      !warnings
  in
  if not has_sibling_warning then
    failwith "expected sibling conditional warning";

  print_endline "All template ppx diagnostics tests passed!";
  ()

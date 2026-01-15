open Solid_ml_browser
open Dom

module H = Html

let fail msg =
  raise (Failure msg)

let assert_eq ~name a b =
  if a <> b then fail (name ^ ": expected " ^ b ^ ", got " ^ a)

let error_stack : exn -> string option =
  [%mel.raw
    {| function(exn) {
      if (exn && exn.stack) return String(exn.stack);
      if (exn instanceof Error && exn.stack) return String(exn.stack);
      return null;
    } |}]

let set_result status ?error ?stack message =
  match get_element_by_id (document ()) "test-result" with
  | None -> ()
  | Some el ->
    set_attribute el "data-test-result" status;
    (match error with
     | None -> ()
     | Some e -> set_attribute el "data-test-error" e);
    (match stack with
     | None -> ()
     | Some s -> set_attribute el "data-test-stack" s);
    set_text_content el message

let test_instantiate_text_slot () =
  let template =
    H.Template.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let inst = H.Template.instantiate template in
  let slot = H.Template.bind_text inst ~id:0 ~path:[| 0 |] in
  H.Template.set_text slot "Hello";
  match H.Template.root inst with
  | H.Element el ->
    assert_eq ~name:"csr textContent" (get_text_content el) "Hello"
  | _ -> fail "csr: expected Template.root to be an Element"

let test_hydrate_text_slot () =
  let template =
    H.Template.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  (* attach to DOM so we exercise the real tree *)
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let inst = H.Template.hydrate ~root template in
  let slot = H.Template.bind_text inst ~id:0 ~path:[| 0 |] in
  H.Template.set_text slot "Hydrated";
  assert_eq ~name:"hydrate textContent" (get_text_content root) "Hydrated"

let () =
  try
    test_instantiate_text_slot ();
    test_hydrate_text_slot ();
    set_result "PASS" "PASS"
  with exn ->
    let err_msg = exn_to_string exn in
    let stack = error_stack exn in
    (match stack with
     | None -> ()
     | Some s -> error s);
    set_result "FAIL" ~error:err_msg ?stack ("FAIL: " ^ err_msg)

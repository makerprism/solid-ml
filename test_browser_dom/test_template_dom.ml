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

module Link (Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV) = struct
  open Env

  let render_opt ~href ~label () =
    Html.a
      ~href:
        (Solid_ml_template_runtime.Tpl.attr_opt ~name:"href" (fun () -> Signal.get href))
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get label) ]
      ()

  let render_attr ~href ~label () =
    Html.a
      ~href:
        (Solid_ml_template_runtime.Tpl.attr ~name:"href" (fun () -> Signal.get href))
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get label) ]
      ()
end

let test_compiled_attr_opt () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let href, set_href = Solid_ml_browser.Env.Signal.create (Some "/a") in
  let label, set_label = Solid_ml_browser.Env.Signal.create "Link" in

  let module C = Link (Solid_ml_browser.Env) in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node = C.render_opt ~href ~label () in
      Html.append_to_element root node)
  in

  let children = get_child_nodes root in
  if Array.length children <> 1 then fail "compiled attr: expected one child";
  let a_el = element_of_node children.(0) in

  assert_eq ~name:"compiled href initial" (Option.value (get_attribute a_el "href") ~default:"") "/a";
  assert_eq ~name:"compiled text initial" (Option.value (node_text_content (node_of_element a_el)) ~default:"") "Link";

  set_href None;
  if get_attribute a_el "href" <> None then fail "compiled href: expected removed";

  set_href (Some "/b");
  assert_eq ~name:"compiled href updated" (Option.value (get_attribute a_el "href") ~default:"") "/b";

  set_label "Next";
  assert_eq ~name:"compiled text updated" (Option.value (node_text_content (node_of_element a_el)) ~default:"") "Next";

  dispose ()

let test_compiled_attr () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let href, set_href = Solid_ml_browser.Env.Signal.create "/a?x=<y>" in
  let label, set_label = Solid_ml_browser.Env.Signal.create "Link" in

  let module C = Link (Solid_ml_browser.Env) in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node = C.render_attr ~href ~label () in
      Html.append_to_element root node)
  in

  let children = get_child_nodes root in
  if Array.length children <> 1 then fail "compiled attr: expected one child";
  let a_el = element_of_node children.(0) in

  assert_eq ~name:"compiled attr initial" (Option.value (get_attribute a_el "href") ~default:"") "/a?x=<y>";

  set_href "";
  assert_eq ~name:"compiled attr empty" (Option.value (get_attribute a_el "href") ~default:"") "";

  set_href "/b";
  assert_eq ~name:"compiled attr updated" (Option.value (get_attribute a_el "href") ~default:"") "/b";

  set_label "Next";
  assert_eq ~name:"compiled attr text updated" (Option.value (node_text_content (node_of_element a_el)) ~default:"") "Next";

  dispose ()

let () =
  try
    test_instantiate_text_slot ();
    test_hydrate_text_slot ();
    test_compiled_attr_opt ();
    test_compiled_attr ();
    set_result "PASS" "PASS"
  with exn ->
    let err_msg = exn_to_string exn in
    let stack = error_stack exn in
    (match stack with
     | None -> ()
     | Some s -> error s);
    set_result "FAIL" ~error:err_msg ?stack ("FAIL: " ^ err_msg)

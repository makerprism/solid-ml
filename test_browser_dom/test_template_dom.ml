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

let test_instantiate_nodes_slot () =
  let template =
    H.Template.compile
      ~segments:[| "<div><!--$-->"; "<!--$--></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let inst = H.Template.instantiate template in
  let slot = H.Template.bind_nodes inst ~id:0 ~path:[| 1 |] in
  let value = H.span ~id:"x" ~children:[ H.text "OK" ] () in
  H.Template.set_nodes slot value;
  match H.Template.root inst with
  | H.Element el ->
    let children = get_child_nodes el in
    if Array.length children <> 3 then
      fail ("csr nodes: expected 3 childNodes, got " ^ string_of_int (Array.length children));
    if not (is_comment children.(0)) then fail "csr nodes: expected opening marker";
    if not (is_element children.(1)) then fail "csr nodes: expected inserted element";
    if not (is_comment children.(2)) then fail "csr nodes: expected closing marker";
    let span = element_of_node children.(1) in
    assert_eq ~name:"csr nodes inserted" (get_id span) "x";
    assert_eq ~name:"csr nodes text" (get_text_content el) "OK"
  | _ -> fail "csr nodes: expected Template.root to be an Element"

let test_hydrate_normalizes_nodes_regions () =
  (* SSR may render content inside a node slot region. For path-stable hydration we
     clear it so elements after the region are still addressable by CSR paths. *)
  let template =
    H.Template.compile
      ~segments:[| "<div><!--$-->"; "<!--$--><a id=\"after\"></a></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<!--$--><span id=\"x\"></span><!--$--><a id=\"after\"></a>";

  let inst = H.Template.hydrate ~root template in

  (* After normalization, <a> should be at index 2: [$, $, <a>] *)
  let a_el = H.Template.bind_element inst ~id:0 ~path:[| 2 |] in
  assert_eq ~name:"hydrate nodes normalize binds after" (get_id a_el) "after";

  let slot = H.Template.bind_nodes inst ~id:0 ~path:[| 1 |] in
  H.Template.set_nodes slot (H.span ~id:"y" ~children:[] ());
  let children = get_child_nodes root in
  if Array.length children <> 4 then
    fail ("hydrate nodes: expected 4 childNodes, got " ^ string_of_int (Array.length children));
  let inserted = element_of_node children.(1) in
  assert_eq ~name:"hydrate nodes inserted" (get_id inserted) "y"

let test_hydrate_normalizes_slot_text_nodes () =
  (* Simulate SSR markup for a compiled template where a non-empty text slot
     appears before an element we want to bind.

     Without normalization, the slot text node would shift child indices and
     [bind_element] would locate the wrong node during hydration. *)
  let template =
    H.Template.compile
      ~segments:[| "<div><!--#-->"; "<!--#--><a id=\"link\"></a></div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<!--#-->Hello<!--#--><a id=\"link\"></a>";

  let inst = H.Template.hydrate ~root template in

  (* After normalization, <a> should be the 3rd child: [#, #, <a>] *)
  let a_el = H.Template.bind_element inst ~id:0 ~path:[| 2 |] in
  assert_eq ~name:"hydrate normalize binds a" (get_id a_el) "link";

  (* Slot insertion is still between the markers. *)
  let slot = H.Template.bind_text inst ~id:0 ~path:[| 1 |] in
  H.Template.set_text slot "Hydrated";
  assert_eq ~name:"hydrate normalize textContent" (get_text_content root) "Hydrated"

let test_hydrate_normalizes_nested_slot_text_nodes () =
  (* Same scenario as above, but nested inside an element, to ensure
     normalization walks the subtree. *)
  let template =
    H.Template.compile
      ~segments:
        [| "<div><p><!--#-->"; "<!--#--><a id=\"link\"></a></p></div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<p><!--#-->Hello<!--#--><a id=\"link\"></a></p>";

  let inst = H.Template.hydrate ~root template in

  (* root -> p -> [#, #, <a>] after normalization *)
  let a_el = H.Template.bind_element inst ~id:0 ~path:[| 0; 2 |] in
  assert_eq ~name:"hydrate normalize nested binds a" (get_id a_el) "link";

  let slot = H.Template.bind_text inst ~id:0 ~path:[| 0; 1 |] in
  H.Template.set_text slot "Hydrated";
  assert_eq ~name:"hydrate normalize nested textContent" (get_text_content root) "Hydrated"

let test_hydrate_does_not_remove_non_text_between_markers () =
  (* Normalization must only remove text nodes between paired markers.
     If an element sits between the markers, it should remain intact. *)
  let template =
    H.Template.compile
      ~segments:[| "<div></div>" |]
      ~slot_kinds:[||]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "A<!--#--><span id=\"x\"></span><!--#-->B";

  let _inst = H.Template.hydrate ~root template in

  let children = get_child_nodes root in
  if Array.length children <> 5 then
    fail ("hydrate negative: expected 5 childNodes, got " ^ string_of_int (Array.length children));

  if not (is_text children.(0)) then fail "hydrate negative: expected text[0]";
  if not (is_comment children.(1)) then fail "hydrate negative: expected comment[1]";
  if not (is_element children.(2)) then fail "hydrate negative: expected element[2]";
  if not (is_comment children.(3)) then fail "hydrate negative: expected comment[3]";
  if not (is_text children.(4)) then fail "hydrate negative: expected text[4]";

  assert_eq ~name:"hydrate negative prefix" (Option.value (node_text_content children.(0)) ~default:"") "A";
  let span = element_of_node children.(2) in
  assert_eq ~name:"hydrate negative span id" (get_id span) "x";
  assert_eq ~name:"hydrate negative suffix" (Option.value (node_text_content children.(4)) ~default:"") "B"

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

  (* Regression case: static text + slot + static text must not get its static
     suffix overwritten when binding the slot. *)
  let render_static_slot_static ~label () =
    Html.p
      ~children:
        [ Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get label);
          Html.text "!" ]
      ()

  (* Simulates MLX formatting whitespace around a nested intrinsic <a>. *)
  let render_nested_formatting ~href ~label () =
    Html.div
      ~children:
        [ Html.text "\n  ";
          Html.a
            ~href:
              (Solid_ml_template_runtime.Tpl.attr
                 ~name:"href"
                 (fun () -> Signal.get href))
            ~children:
              [ Html.text "\n    ";
                Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get label);
                Html.text "\n  " ]
            ();
          Html.text "\n" ]
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

let test_compiled_attr_nested () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let href, set_href = Solid_ml_browser.Env.Signal.create "/a" in
  let label, set_label = Solid_ml_browser.Env.Signal.create "Link" in

  let module C = Link (Solid_ml_browser.Env) in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let link = C.render_attr ~href ~label () in
      let wrapper =
        Html.div
          ~children:
            [ Html.text "(";
              link;
              Html.text ")" ]
          ()
      in
      Html.append_to_element root wrapper)
  in

  let children = get_child_nodes root in
  if Array.length children <> 1 then fail "nested attr: expected one child";

  (* root -> div -> [text, a, text] *)
  let div_el = element_of_node children.(0) in
  let div_children = get_child_nodes div_el in
  if Array.length div_children < 2 then fail "nested attr: expected a child";
  let a_el = element_of_node div_children.(1) in

  assert_eq ~name:"nested href initial" (Option.value (get_attribute a_el "href") ~default:"") "/a";

  set_href "/b";
  assert_eq ~name:"nested href updated" (Option.value (get_attribute a_el "href") ~default:"") "/b";

  set_label "Next";
  assert_eq ~name:"nested text updated" (Option.value (node_text_content (node_of_element a_el)) ~default:"") "Next";

  dispose ()

let test_compiled_nested_intrinsic_formatting () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let href, set_href = Solid_ml_browser.Env.Signal.create "/a" in
  let label, set_label = Solid_ml_browser.Env.Signal.create "Link" in

  let module C = Link (Solid_ml_browser.Env) in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node = C.render_nested_formatting ~href ~label () in
      Html.append_to_element root node)
  in

  (* root -> div (compiled) -> [a] (no formatting whitespace) *)
  let children = get_child_nodes root in
  if Array.length children <> 1 then fail "nested formatting: expected one child";
  let div_el = element_of_node children.(0) in
  let div_children = get_child_nodes div_el in
  if Array.length div_children <> 1 then
    fail
      ("nested formatting: expected one <a> child, got " ^ string_of_int (Array.length div_children));
  let a_el = element_of_node div_children.(0) in

  assert_eq ~name:"nested formatting href initial" (Option.value (get_attribute a_el "href") ~default:"") "/a";

  set_href "/b";
  assert_eq ~name:"nested formatting href updated" (Option.value (get_attribute a_el "href") ~default:"") "/b";

  set_label "Next";
  assert_eq ~name:"nested formatting text updated" (Option.value (node_text_content (node_of_element a_el)) ~default:"") "Next";

  dispose ()

let test_text_slot_static_suffix_preserved () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let label, set_label = Solid_ml_browser.Env.Signal.create "World" in
  let module C = Link (Solid_ml_browser.Env) in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node = C.render_static_slot_static ~label () in
      Html.append_to_element root node)
  in

  let children = get_child_nodes root in
  if Array.length children <> 1 then fail "slot static: expected one child";
  let p_el = element_of_node children.(0) in

  (* Expect: ["Hello ", <!--#-->, "World", <!--#-->, "!"] *)
  let p_children = get_child_nodes p_el in
  if Array.length p_children <> 5 then
    fail ("slot static: expected 5 childNodes, got " ^ string_of_int (Array.length p_children));

  if not (is_text p_children.(0)) then fail "slot static: expected text[0]";
  if not (is_comment p_children.(1)) then fail "slot static: expected comment[1]";
  if not (is_text p_children.(2)) then fail "slot static: expected text[2]";
  if not (is_comment p_children.(3)) then fail "slot static: expected comment[3]";
  if not (is_text p_children.(4)) then fail "slot static: expected text[4]";

  assert_eq ~name:"slot static prefix" (Option.value (node_text_content p_children.(0)) ~default:"") "Hello ";
  assert_eq ~name:"slot static value" (Option.value (node_text_content p_children.(2)) ~default:"") "World";
  assert_eq ~name:"slot static suffix" (Option.value (node_text_content p_children.(4)) ~default:"") "!";

  set_label "Ada";
  assert_eq ~name:"slot static updated" (Option.value (node_text_content p_children.(2)) ~default:"") "Ada";
  assert_eq ~name:"slot static suffix stays" (Option.value (node_text_content p_children.(4)) ~default:"") "!";

  dispose ()

let () =
  try
    test_instantiate_text_slot ();
    test_instantiate_nodes_slot ();
    test_hydrate_text_slot ();
    test_hydrate_normalizes_nodes_regions ();
    test_hydrate_normalizes_slot_text_nodes ();
    test_hydrate_normalizes_nested_slot_text_nodes ();
    test_hydrate_does_not_remove_non_text_between_markers ();
    test_compiled_attr_opt ();
    test_compiled_attr ();
    test_compiled_attr_nested ();
    test_compiled_nested_intrinsic_formatting ();
    test_text_slot_static_suffix_preserved ();
    set_result "PASS" "PASS"
  with exn ->
    let err_msg = exn_to_string exn in
    let stack = error_stack exn in
    (match stack with
     | None -> ()
     | Some s -> error s);
    set_result "FAIL" ~error:err_msg ?stack ("FAIL: " ^ err_msg)

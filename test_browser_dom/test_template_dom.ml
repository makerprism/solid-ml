open Solid_ml_browser
module Signal = Reactive.Signal
module Effect = Solid_ml_browser.Env.Effect
module Owner = Solid_ml_browser.Env.Owner
open Dom

module H = Html
module T = Html.Internal_template

type keyed_test_item = {
  id : string;
  label : string;
}

let fail msg =
  raise (Failure msg)

let assert_eq ~name a b =
  if a <> b then fail (name ^ ": expected " ^ b ^ ", got " ^ a)

let decode_int (json : Js.Json.t) : int option =
  match Js.Json.decodeNumber json with
  | None -> None
  | Some v -> Some (int_of_float v)

let set_hydration_data (json : string) : unit =
  let _ = json in
  [%mel.raw {| window.__SOLID_ML_DATA__ = JSON.parse(json) |}]

let init_event_replay () : unit =
  [%mel.raw
    {| (function(){
      if (window.__SOLID_ML_EVENT_REPLAY__) return;
      var queue = [];
      var types = ['click','input','change','submit','keydown','keyup','pointerdown'];
      var esc = (window.CSS && CSS.escape) ? CSS.escape : function(s){ return s.replace(/([^\w-])/g,'\\$1'); };
      var replay = {
        queue: queue,
        types: types,
        handler: function(e){
          var target = e.target;
          if (!target) return;
          var selector = null;
          if (!target.id) {
            var parts = [];
            var node = target;
            while (node && node.nodeType === 1 && node !== document.body) {
              var name = node.tagName.toLowerCase();
              var parent = node.parentElement;
              if (!parent) break;
              var index = 1;
              var siblings = parent.children;
              for (var i = 0; i < siblings.length; i++) {
                if (siblings[i] === node) { index = i + 1; break; }
              }
              parts.unshift(name + ':nth-child(' + index + ')');
              node = parent;
            }
            selector = parts.length ? parts.join('>') : null;
          } else {
            selector = '#' + esc(target.id);
          }
          var item = {type:e.type,target:target,selector:selector,value:null,checked:null,key:null,code:null,repeat:false,ctrlKey:false,shiftKey:false,altKey:false,metaKey:false,clientX:null,clientY:null,button:null,buttons:null,pointerId:null,pointerType:null,pressure:null,inputType:null};
          if (e.type === 'input' || e.type === 'change') { item.value = target.value; item.checked = target.checked; }
          if (e.type === 'keydown' || e.type === 'keyup') {
            item.key = e.key || null; item.code = e.code || null; item.repeat = !!e.repeat;
            item.ctrlKey = !!e.ctrlKey; item.shiftKey = !!e.shiftKey;
            item.altKey = !!e.altKey; item.metaKey = !!e.metaKey;
          }
          if (e.type === 'click' || e.type === 'pointerdown') {
            item.clientX = typeof e.clientX === 'number' ? e.clientX : null;
            item.clientY = typeof e.clientY === 'number' ? e.clientY : null;
            item.button = typeof e.button === 'number' ? e.button : null;
            item.buttons = typeof e.buttons === 'number' ? e.buttons : null;
          }
          if (e.type === 'pointerdown') {
            item.pointerId = typeof e.pointerId === 'number' ? e.pointerId : null;
            item.pointerType = e.pointerType || null;
            item.pressure = typeof e.pressure === 'number' ? e.pressure : null;
          }
          queue.push(item);
        },
        listen: function(){ types.forEach(function(t){ document.addEventListener(t, replay.handler, true); }); },
        stop: function(){ types.forEach(function(t){ document.removeEventListener(t, replay.handler, true); }); },
        resolve: function(item){
          var target = item.target;
          if (target && target.isConnected) return target;
          if (item.selector) {
            var found = document.querySelector(item.selector);
            if (found) return found;
          }
          return target;
        },
        replay: function(){
          replay.stop();
          var items = queue.slice();
          queue.length = 0;
          items.forEach(function(item){
            var target = replay.resolve(item);
            if (!target) return;
            if (item.value !== null) { try { target.value = item.value; } catch (_e) {} }
            if (item.checked !== null) { try { target.checked = item.checked; } catch (_e) {} }
            var evt;
            if (item.key !== null || item.code !== null) {
              evt = new KeyboardEvent(item.type, {bubbles:true,cancelable:true,key:item.key||'',code:item.code||'',repeat:item.repeat,ctrlKey:item.ctrlKey,shiftKey:item.shiftKey,altKey:item.altKey,metaKey:item.metaKey});
            } else if (item.pointerId !== null && typeof PointerEvent !== 'undefined') {
              evt = new PointerEvent(item.type, {bubbles:true,cancelable:true,clientX:item.clientX||0,clientY:item.clientY||0,button:item.button||0,buttons:item.buttons||0,pointerId:item.pointerId,pointerType:item.pointerType||'mouse',pressure:item.pressure||0});
            } else if (item.clientX !== null) {
              evt = new MouseEvent(item.type, {bubbles:true,cancelable:true,clientX:item.clientX||0,clientY:item.clientY||0,button:item.button||0,buttons:item.buttons||0});
            } else {
              evt = new Event(item.type, {bubbles:true,cancelable:true});
            }
            target.dispatchEvent(evt);
          });
        }
      };
      window.__SOLID_ML_EVENT_REPLAY__ = replay;
      replay.listen();
    })() |}]

let dispatch_click (el : element) : unit =
  let _ = el in
  [%mel.raw {| el.dispatchEvent(new Event('click', {bubbles:true,cancelable:true})) |}]

let dispatch_input (el : element) : unit =
  let _ = el in
  [%mel.raw {| el.dispatchEvent(new Event('input', {bubbles:true,cancelable:true})) |}]

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
    T.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let inst = T.instantiate template in
  let slot = T.bind_text inst ~id:0 ~path:[| 0 |] in
  T.set_text slot "Hello";
  match T.root inst with
  | H.Element el ->
    assert_eq ~name:"csr textContent" (get_text_content el) "Hello"
  | _ -> fail "csr: expected Template.root to be an Element"

let test_hydrate_text_slot () =
  let template =
    T.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  (* Server DOM: container with one template root element. *)
  Dom.set_inner_html root "<div></div>";

  let slot_ref = ref None in

  let dispose =
    Render.hydrate root (fun () ->
        let inst = T.instantiate template in
        slot_ref := Some (T.bind_text inst ~id:0 ~path:[| 0 |]);
        H.empty)
  in

  (match !slot_ref with
   | None -> fail "hydrate text slot: did not bind slot"
   | Some slot -> T.set_text slot "Hydrated");

  assert_eq ~name:"hydrate textContent" (get_text_content root) "Hydrated";
  dispose ()

let test_hydrate_reactive_text_marker_adoption () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><!--hk:0-->Hello<!--/hk--></div>";

  let text_signal, set_text = Solid_ml_browser.Env.Signal.create "Hello" in

  let dispose =
    Render.hydrate root (fun () ->
      Html.div
        ~children:[ Html.reactive_text_string text_signal ]
        ())
  in

  set_text "Updated";
  assert_eq ~name:"hydrate reactive text updated" (get_text_content root) "Updated";
  dispose ()

let test_instantiate_nodes_slot () =
  let template =
    T.compile
      ~segments:[| "<div><!--$-->"; "<!--$--></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let inst = T.instantiate template in
  let slot = T.bind_nodes inst ~id:0 ~path:[| 1 |] in
  let value = H.span ~id:"x" ~children:[ H.text "OK" ] () in
  T.set_nodes slot value;
  match T.root inst with
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

let test_hydrate_adjacent_nodes_slots () =
  let template =
    T.compile
      ~segments:[| "<div><!--$-->"; "<!--$--><!--$-->"; "<!--$--></div>" |]
      ~slot_kinds:[| `Nodes; `Nodes |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><!--$-->A<!--$--><!--$-->B<!--$--></div>";

  let slot_a = ref None in
  let slot_b = ref None in

  let dispose =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in
      slot_a := Some (T.bind_nodes inst ~id:0 ~path:[| 1 |]);
      slot_b := Some (T.bind_nodes inst ~id:1 ~path:[| 2 |]);
      H.empty)
  in

  (match !slot_a with
   | None -> fail "hydrate nodes slot A: did not bind"
   | Some slot -> T.set_nodes slot (H.text "A"));
  (match !slot_b with
   | None -> fail "hydrate nodes slot B: did not bind"
   | Some slot -> T.set_nodes slot (H.text "B"));

  assert_eq ~name:"hydrate adjacent nodes" (get_text_content root) "AB";
  dispose ()

let test_hydrate_adjacent_show_when () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><!--$-->A<!--$--><!--$-->B<!--$--></div>";

  let first, _set_first = Solid_ml_browser.Env.Signal.create true in
  let second, _set_second = Solid_ml_browser.Env.Signal.create true in

  let dispose =
    Render.hydrate root (fun () ->
      Html.div
        ~children:
          [ Solid_ml_template_runtime.Tpl.show_when
              ~when_:(fun () -> Signal.get first)
              (fun () -> Html.text "A");
            Solid_ml_template_runtime.Tpl.show_when
              ~when_:(fun () -> Signal.get second)
              (fun () -> Html.text "B") ]
        ())
  in

  assert_eq ~name:"hydrate adjacent show_when" (get_text_content root) "AB";
  dispose ()

let test_hydrate_normalizes_nodes_regions () =
  (* SSR may render content inside a node slot region. For path-stable hydration we
     clear it so elements after the region are still addressable by CSR paths. *)
  let template =
    T.compile
      ~segments:[| "<div><!--$-->"; "<!--$--><a id=\"after\"></a></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  (* Server DOM: container with template root element containing region markers. *)
  set_inner_html root
    "<div><!--$--><span id=\"x\"></span><!--$--><a id=\"after\"></a></div>";

  let slot_ref = ref None in

  let dispose =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in


      (* After normalization, <a> should be at index 2: [$, $, <a>] *)
      let a_el = T.bind_element inst ~id:0 ~path:[| 2 |] in
      assert_eq ~name:"hydrate nodes normalize binds after" (get_id a_el) "after";

      slot_ref := Some (T.bind_nodes inst ~id:0 ~path:[| 1 |]);
      H.empty)
  in

  (match !slot_ref with
   | None -> fail "hydrate nodes: did not bind nodes slot"
   | Some slot -> T.set_nodes slot (H.span ~id:"y" ~children:[] ()));

  let children = get_child_nodes root in
  if Array.length children <> 1 then
    fail ("hydrate nodes: expected 1 childNode (template root), got " ^ string_of_int (Array.length children));

  let root_el = element_of_node children.(0) in
  let root_children = get_child_nodes root_el in
  if Array.length root_children <> 4 then
    fail
      ("hydrate nodes: expected 4 root childNodes, got "
      ^ string_of_int (Array.length root_children));

  let inserted = element_of_node root_children.(1) in
  assert_eq ~name:"hydrate nodes inserted" (get_id inserted) "y";

  dispose ()

let test_hydrate_normalizes_slot_text_nodes () =
  (* Simulate SSR markup for a compiled template where a non-empty text slot
     appears before an element we want to bind.

     Without normalization, the slot text node would shift child indices and
     [bind_element] would locate the wrong node during hydration. *)
  let template =
    T.compile
      ~segments:[| "<div><!--#-->"; "<!--#--><a id=\"link\"></a></div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><!--#-->Hello<!--#--><a id=\"link\"></a></div>";

  let slot_ref = ref None in

  let dispose =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in


      (* After normalization, <a> should be the 3rd child: [#, #, <a>] *)
      let a_el = T.bind_element inst ~id:0 ~path:[| 2 |] in
      assert_eq ~name:"hydrate normalize binds a" (get_id a_el) "link";

      (* Slot insertion is still between the markers. *)
      slot_ref := Some (T.bind_text inst ~id:0 ~path:[| 1 |]);
      H.empty)
  in

  (match !slot_ref with
   | None -> fail "hydrate normalize: did not bind text slot"
   | Some slot -> T.set_text slot "Hydrated");

  assert_eq ~name:"hydrate normalize textContent" (get_text_content root) "Hydrated";
  dispose ()

let test_hydrate_normalizes_nested_slot_text_nodes () =
  (* Same scenario as above, but nested inside an element, to ensure
     normalization walks the subtree. *)
  let template =
    T.compile
      ~segments:
        [| "<div><p><!--#-->"; "<!--#--><a id=\"link\"></a></p></div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><p><!--#-->Hello<!--#--><a id=\"link\"></a></p></div>";

  let slot_ref = ref None in

  let dispose =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in


      (* root -> p -> [#, #, <a>] after normalization *)
      let a_el = T.bind_element inst ~id:0 ~path:[| 0; 2 |] in
      assert_eq ~name:"hydrate normalize nested binds a" (get_id a_el) "link";

      slot_ref := Some (T.bind_text inst ~id:0 ~path:[| 0; 1 |]);
      H.empty)
  in

  (match !slot_ref with
   | None -> fail "hydrate normalize nested: did not bind text slot"
   | Some slot -> T.set_text slot "Hydrated");

  assert_eq ~name:"hydrate normalize nested textContent" (get_text_content root) "Hydrated";
  dispose ()

let test_hydrate_does_not_remove_non_text_between_markers () =
  (* Normalization must only remove text nodes between paired markers.
     If an element sits between the markers, it should remain intact. *)
  let template =
    T.compile
      ~segments:[| "<div></div>" |]
      ~slot_kinds:[||]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div>A<!--#--><span id=\"x\"></span><!--#-->B</div>";

  let dispose =
    Render.hydrate root (fun () ->
      let _inst = T.instantiate template in
      H.empty)
  in
  dispose ();

  let children = get_child_nodes root in
  if Array.length children <> 1 then
    fail
      ("hydrate negative: expected 1 childNode (template root), got "
      ^ string_of_int (Array.length children));

  let root_el = element_of_node children.(0) in
  let root_children = get_child_nodes root_el in

  if Array.length root_children <> 5 then
    fail
      ("hydrate negative: expected 5 root childNodes, got "
      ^ string_of_int (Array.length root_children));

  if not (is_text root_children.(0)) then fail "hydrate negative: expected text[0]";
  if not (is_comment root_children.(1)) then fail "hydrate negative: expected comment[1]";
  if not (is_element root_children.(2)) then fail "hydrate negative: expected element[2]";
  if not (is_comment root_children.(3)) then fail "hydrate negative: expected comment[3]";
  if not (is_text root_children.(4)) then fail "hydrate negative: expected text[4]";

  assert_eq ~name:"hydrate negative prefix"
    (Option.value (node_text_content root_children.(0)) ~default:"")
    "A";
  let span = element_of_node root_children.(2) in
  assert_eq ~name:"hydrate negative span id" (get_id span) "x";
  assert_eq ~name:"hydrate negative suffix"
    (Option.value (node_text_content root_children.(4)) ~default:"")
    "B"

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

let test_keyed_updates_on_value_change () =
  let template =
    T.compile
      ~segments:[| "<ul><!--$-->"; "<!--$--></ul>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let inst = T.instantiate template in
  let slot = T.bind_nodes inst ~id:0 ~path:[| 1 |] in
  let disposed = ref 0 in
  let render (item : keyed_test_item) =
    let node = H.li ~children:[ H.text item.label ] () in
    let dispose () = disposed := !disposed + 1 in
    (node, dispose)
  in
  let items1 = [ { id = "a"; label = "Alpha" } ] in
  let items2 = [ { id = "a"; label = "Beta" } ] in
  T.set_nodes_keyed slot ~key:(fun item -> item.id) ~render items1;
  (match T.root inst with
   | H.Element el ->
     assert_eq ~name:"keyed initial text" (get_text_content el) "Alpha"
   | _ -> fail "keyed update: expected Template.root to be an Element");
  T.set_nodes_keyed slot ~key:(fun item -> item.id) ~render items2;
  (match T.root inst with
   | H.Element el ->
     assert_eq ~name:"keyed updated text" (get_text_content el) "Beta"
   | _ -> fail "keyed update: expected Template.root to be an Element");
  if !disposed <> 1 then
    fail ("keyed update: expected dispose count 1, got " ^ string_of_int !disposed)

let test_keyed_identity_preserved () =
  let template =
    T.compile
      ~segments:[| "<div><!--$-->"; "<!--$--></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let inst = T.instantiate template in
  let slot = T.bind_nodes inst ~id:0 ~path:[| 1 |] in
  let render (item : keyed_test_item) =
    (H.span ~children:[ H.text item.label ] (), fun () -> ())
  in
  let items1 = [ { id = "a"; label = "Alpha" }; { id = "b"; label = "Beta" } ] in
  let items2 = [ { id = "x"; label = "Xray" } ] @ items1 in
  T.set_nodes_keyed slot ~key:(fun item -> item.id) ~render items1;
  let first_el, second_el =
    match T.root inst with
    | H.Element el ->
      let children = node_child_nodes (node_of_element el) in
      let elements =
        Array.fold_left
          (fun acc node ->
            if is_element node then element_of_node node :: acc else acc)
          []
          children
        |> List.rev
      in
      (match elements with
       | first :: second :: _ -> (first, second)
       | _ -> fail "keyed identity: expected at least two elements")
    | _ -> fail "keyed identity: expected Template.root to be an Element"
  in
  T.set_nodes_keyed slot ~key:(fun item -> item.id) ~render items2;
  (match T.root inst with
   | H.Element el ->
     let children = node_child_nodes (node_of_element el) in
     let elements =
       Array.fold_left
         (fun acc node ->
           if is_element node then element_of_node node :: acc else acc)
         []
         children
       |> List.rev
     in
     (match elements with
      | _new :: first :: second :: _ ->
        if first != first_el then fail "keyed identity: first element changed";
        if second != second_el then fail "keyed identity: second element changed"
      | _ -> fail "keyed identity: expected at least three elements")
   | _ -> fail "keyed identity: expected Template.root to be an Element")

let test_indexed_updates_by_position () =
  let template =
    T.compile
      ~segments:[| "<div><!--$-->"; "<!--$--></div>" |]
      ~slot_kinds:[| `Nodes |]
  in
  let inst = T.instantiate template in
  let slot = T.bind_nodes inst ~id:0 ~path:[| 1 |] in
  let render _idx item = (H.span ~children:[ H.text item ] (), fun () -> ()) in
  T.set_nodes_indexed slot ~render [ "A"; "B" ];
  (match T.root inst with
   | H.Element el -> assert_eq ~name:"indexed initial" (get_text_content el) "AB"
   | _ -> fail "indexed: expected Template.root to be an Element");
  T.set_nodes_indexed slot ~render [ "Z"; "A"; "B" ];
  (match T.root inst with
   | H.Element el -> assert_eq ~name:"indexed update" (get_text_content el) "ZAB"
   | _ -> fail "indexed: expected Template.root to be an Element")

let test_indexed_accessors_update () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let items, set_items = Signal.create [ "A"; "B" ] in
  let dispose =
    Render.render root (fun () ->
      Html.div
        ~children:
          [ Solid_ml_template_runtime.Tpl.each_indexed
              ~items:(fun () -> Signal.get items)
              ~render:(fun ~index ~item ->
                Html.span
                  ~children:
                    [ Html.text (string_of_int (index ()) ^ ":" ^ item ()) ]
                  ()) ]
        ())
  in
  let first_el, second_el =
    let root_children = node_child_nodes (node_of_element root) in
    let container =
      Array.fold_left
        (fun acc node ->
          match acc with
          | Some _ -> acc
          | None -> if is_element node then Some (element_of_node node) else None)
        None
        root_children
    in
    let container =
      match container with
      | Some el -> el
      | None -> fail "indexed accessors: missing container element"
    in
    let children = node_child_nodes (node_of_element container) in
    let elements =
      Array.fold_left
        (fun acc node ->
          if is_element node then element_of_node node :: acc else acc)
        []
        children
      |> List.rev
    in
    (match elements with
     | first :: second :: _ -> (first, second)
     | _ -> fail "indexed accessors: expected at least two elements")
  in
  assert_eq ~name:"indexed accessors initial" (get_text_content root) "0:A1:B";
  set_items [ "X"; "Y" ];
  assert_eq ~name:"indexed accessors update" (get_text_content root) "0:X1:Y";
  let root_children = node_child_nodes (node_of_element root) in
  let container =
    Array.fold_left
      (fun acc node ->
        match acc with
        | Some _ -> acc
        | None -> if is_element node then Some (element_of_node node) else None)
      None
      root_children
  in
  let container =
    match container with
    | Some el -> el
    | None -> fail "indexed accessors: missing container element"
  in
  let children = node_child_nodes (node_of_element container) in
  let elements =
    Array.fold_left
      (fun acc node ->
        if is_element node then element_of_node node :: acc else acc)
      []
      children
    |> List.rev
  in
  (match elements with
   | first :: second :: _ ->
     if first != first_el then fail "indexed accessors: first element changed";
     if second != second_el then fail "indexed accessors: second element changed"
   | _ -> fail "indexed accessors: expected at least two elements");
  dispose ()

let test_template_spread_updates () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let spread_initial =
    Solid_ml_template_runtime.Spread.merge
      (Solid_ml_template_runtime.Spread.attrs [ ("data-x", Some "a") ])
      (Solid_ml_template_runtime.Spread.style [ ("color", Some "red") ])
  in
  let spread, set_spread = Signal.create spread_initial in

  let dispose =
    Render.render root (fun () ->
      Html.div
        ~attrs:(Solid_ml_template_runtime.Tpl.spread (fun () -> Signal.get spread))
        ~children:[ Html.text "Spread" ]
        ())
  in

  let child =
    match query_selector_within root "div" with
    | None -> fail "template spread: missing child"
    | Some el -> el
  in
  assert_eq ~name:"template spread attr" (Option.value (get_attribute child "data-x") ~default:"") "a";
  assert_eq ~name:"template spread style" (Option.value (get_attribute child "style") ~default:"") "color:red";

  let spread_next =
    Solid_ml_template_runtime.Spread.merge
      (Solid_ml_template_runtime.Spread.attrs [ ("data-x", Some "b") ])
      (Solid_ml_template_runtime.Spread.class_list [ ("active", true) ])
  in
  set_spread spread_next;
  assert_eq ~name:"template spread attr updated" (Option.value (get_attribute child "data-x") ~default:"") "b";
  assert_eq ~name:"template spread class updated" (Option.value (get_attribute child "class") ~default:"") "active";

  dispose ()

let test_template_ref_binding () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let seen_tag = ref None in

  let dispose =
    Render.render root (fun () ->
      Html.button
        ~attrs:(Solid_ml_template_runtime.Tpl.ref (fun el -> seen_tag := Some (get_tag_name el)))
        ~children:[ Html.text "Ref" ]
        ())
  in

  (match !seen_tag with
   | Some tag -> assert_eq ~name:"template ref tag" tag "BUTTON"
   | None -> fail "template ref: not invoked");

  dispose ()

let test_template_suspense_boundary () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  let resource = Solid_ml_browser.Resource.create_loading () in

  let dispose =
    Render.render root (fun () ->
      Html.div
        ~children:
          [ Solid_ml_template_runtime.Tpl.suspense
              ~fallback:(fun () -> Html.text "Loading")
              ~render:(fun () ->
                let value =
                  Solid_ml_browser.Resource.read_suspense ~default:"Pending" resource
                in
                Html.text value) ]
        ())
  in

  assert_eq ~name:"template suspense fallback" (get_text_content root) "Loading";
  Solid_ml_browser.Resource.set resource "Ready";
  assert_eq ~name:"template suspense ready" (get_text_content root) "Ready";
  Solid_ml_browser.Resource.set_loading resource;
  assert_eq ~name:"template suspense reload" (get_text_content root) "Loading";
  Solid_ml_browser.Resource.set resource "Ready 2";
  assert_eq ~name:"template suspense ready again" (get_text_content root) "Ready 2";

  dispose ()

let test_multiple_hydration_contexts_isolated () =
  (* Verify that multiple Render.hydrate contexts don't interfere with each other *)
  let template =
    T.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root1 = create_element (document ()) "div" in
  let root2 = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root1);
  append_child body (node_of_element root2);

  set_inner_html root1 "<div>A</div>";
  set_inner_html root2 "<div>B</div>";

  let slot_ref1 = ref None in
  let slot_ref2 = ref None in

  let dispose1 =
    Render.hydrate root1 (fun () ->
      let inst = T.instantiate template in
      slot_ref1 := Some (T.bind_text inst ~id:0 ~path:[| 0 |]);
      H.empty)
  in

  let dispose2 =
    Render.hydrate root2 (fun () ->
      let inst = T.instantiate template in
      slot_ref2 := Some (T.bind_text inst ~id:0 ~path:[| 0 |]);
      H.empty)
  in

  (match !slot_ref1 with
   | None -> fail "multi-hydrate: did not bind slot1"
   | Some slot1 ->
       T.set_text slot1 "Updated1";
       assert_eq ~name:"multi-hydrate root1" (get_text_content root1) "Updated1");

  (match !slot_ref2 with
   | None -> fail "multi-hydrate: did not bind slot2"
   | Some slot2 ->
       T.set_text slot2 "Updated2";
       assert_eq ~name:"multi-hydrate root2" (get_text_content root2) "Updated2");

  (* Ensure disposal is independent *)
  dispose1 ();
  assert_eq ~name:"multi-hydrate after dispose1 root2" (get_text_content root2) "Updated2";

  dispose2 ()

let test_cleanup_removes_listeners () =
  (* Verify that cleanup properly removes reactive listeners *)
  let template =
    T.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div>Initial</div>";

  let label, set_label = Solid_ml_browser.Env.Signal.create "World" in
  let slot_ref = ref None in

  let dispose =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in
      slot_ref := Some (T.bind_text inst ~id:0 ~path:[| 0 |]);
      H.empty)
  in

  (match !slot_ref with
   | None -> fail "cleanup: did not bind slot"
   | Some slot ->
       (* Set up reactive update *)
       let (_signal, dispose) =
          Reactive_core.create_root (fun () ->
            Reactive.Effect.create (fun () ->
              T.set_text slot (Signal.get label)))
        in
       set_label "Hello";
       assert_eq ~name:"cleanup reactive update" (get_text_content root) "Hello";
       dispose ();
       (* After dispose, signal changes should not affect DOM *)
       set_label "Goodbye";
       assert_eq ~name:"cleanup after dispose" (get_text_content root) "Hello");

  dispose ()

let test_state_hydration () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div><!--hk:0-->3<!--/hk--></div>";
  set_hydration_data "{\"count\":3}";

  let initial =
    Solid_ml_browser.State.decode
      ~key:"count"
      ~decode:decode_int
      ~default:0
  in
  let count, set_count = Solid_ml_browser.Env.Signal.create initial in

  let dispose =
    Render.hydrate root (fun () ->
      Html.div
        ~children:[ Html.reactive_text count ]
        ())
  in

  assert_eq ~name:"state hydrate initial" (get_text_content root) "3";
  set_count 4;
  assert_eq ~name:"state hydrate update" (get_text_content root) "4";

  dispose ();
  set_hydration_data "{}"

let test_resource_hydration () =
  set_hydration_data "{\"resource\":{\"status\":\"ready\",\"data\":5}}";
  let fetch_called = ref false in
  let decode_number json =
    match Js.Json.decodeNumber json with
    | None -> None
    | Some v -> Some (int_of_float v)
  in
  let resource =
    Solid_ml_browser.Resource.create_with_hydration
      ~key:"resource"
      ~decode:decode_number
      (fun () -> fetch_called := true; 7)
  in
  (match Solid_ml_browser.Resource.get_data resource with
   | Some v -> if v <> 5 then fail "resource hydrate: expected value 5"
   | None -> fail "resource hydrate: expected ready state");
  if !fetch_called then fail "resource hydrate: fetcher should not run";
  set_hydration_data "{}"

let test_event_replay_click () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  set_inner_html root "<button id=\"btn\">Click</button>";

  init_event_replay ();

  let clicked = ref 0 in
  (match query_selector_within root "#btn" with
   | None -> fail "event replay: missing button"
   | Some button -> dispatch_click button);

  let dispose =
    Render.hydrate root (fun () ->
      Html.button
        ~id:"btn"
        ~onclick:(fun _ -> clicked := !clicked + 1)
        ~children:[Html.text "Click"]
        ())
  in

  if !clicked <> 1 then
    fail ("event replay: expected click count 1, got " ^ string_of_int !clicked);

  dispose ()

let test_hydration_error_context_clears () =
  (* Verify that hydration context is properly cleared even on error *)
  let template =
    T.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);

  set_inner_html root "<div>Initial</div>";

  (* First hydration succeeds *)
  let dispose1 =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in
      let slot = T.bind_text inst ~id:0 ~path:[| 0 |] in
      T.set_text slot "First";
      H.empty)
  in

  assert_eq ~name:"error clear first" (get_text_content root) "First";
  dispose1 ();

  (* Second hydration with error *)
  try
    let _dispose2 =
      Render.hydrate root (fun () ->
        let _inst = T.instantiate template in
        fail "Intentional error for context clear test")
    in
    fail "Expected exception not raised"
  with Failure _ ->
    (* Expected - context should be cleared *)
    ();

  (* Third hydration should work normally *)
  let dispose3 =
    Render.hydrate root (fun () ->
      let inst = T.instantiate template in
      let slot = T.bind_text inst ~id:0 ~path:[| 0 |] in
      T.set_text slot "Third";
      H.empty)
  in

  assert_eq ~name:"error clear third" (get_text_content root) "Third";
  dispose3 ()

let test_template_reactive_text () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let message, set_message = Solid_ml_browser.Env.Signal.create "Hello" in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      Html.append_to_element root
        (Solid_ml_browser.Env.Html.div
           ~children:[
             Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get message)
           ]
           ())
    )
  in

  assert_eq ~name:"tpl.text initial" (get_text_content root) "Hello";
  set_message "World";
  assert_eq ~name:"tpl.text update" (get_text_content root) "World";
  dispose ()

let test_template_show_when () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let visible, set_visible = Solid_ml_browser.Env.Signal.create false in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      Html.append_to_element root
        (Solid_ml_browser.Env.Html.div
           ~children:[
             Solid_ml_template_runtime.Tpl.show_when
               ~when_:(fun () -> Signal.get visible)
               (fun () -> Solid_ml_browser.Env.Html.text "Shown")
           ]
           ())
    )
  in

  assert_eq ~name:"tpl.show_when initial" (get_text_content root) "";
  set_visible true;
  assert_eq ~name:"tpl.show_when update" (get_text_content root) "Shown";
  dispose ()

let test_template_bind_input () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let value, set_value = Solid_ml_browser.Env.Signal.create "start" in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      Html.append_to_element root
        (Solid_ml_browser.Env.Html.input
           ~value:
             (Solid_ml_template_runtime.Tpl.bind_input
                ~signal:(fun () -> Signal.get value)
                ~setter:set_value)
           ())
    )
  in

  let children = get_child_nodes root in
  let input_el = element_of_node children.(0) in
  assert_eq ~name:"tpl.bind_input initial" (element_value input_el) "start";
  element_set_value input_el "next";
  dispatch_input input_el;
  assert_eq ~name:"tpl.bind_input update" (Signal.get value) "next";
  dispose ()

let test_template_auto_bool_attr () =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  let enabled, set_enabled = Solid_ml_browser.Env.Signal.create false in

  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      Html.append_to_element root
        (Solid_ml_browser.Env.Html.button
           ~disabled:(fun () -> not (Signal.get enabled))
           ~children:[ Solid_ml_browser.Env.Html.text "Save" ]
           ())
    )
  in

  let button_el = element_of_node (get_child_nodes root).(0) in
  (match get_attribute button_el "disabled" with
   | Some _ -> ()
   | None -> fail "tpl.auto bool attr: disabled missing");
  set_enabled true;
  (match get_attribute button_el "disabled" with
   | Some _ -> fail "tpl.auto bool attr: disabled should be removed"
   | None -> ());
  dispose ()


let () =
  try
    test_instantiate_text_slot ();
    test_instantiate_nodes_slot ();
    test_hydrate_adjacent_nodes_slots ();
    test_hydrate_adjacent_show_when ();
    test_hydrate_text_slot ();
    test_hydrate_reactive_text_marker_adoption ();
    test_hydrate_normalizes_nodes_regions ();
    test_hydrate_normalizes_slot_text_nodes ();
    test_hydrate_normalizes_nested_slot_text_nodes ();
    test_hydrate_does_not_remove_non_text_between_markers ();
    test_compiled_attr_opt ();
    test_compiled_attr ();
    test_compiled_attr_nested ();
    test_compiled_nested_intrinsic_formatting ();
    test_text_slot_static_suffix_preserved ();
    test_keyed_updates_on_value_change ();
    test_keyed_identity_preserved ();
    test_indexed_updates_by_position ();
    test_indexed_accessors_update ();
    test_template_spread_updates ();
    test_template_ref_binding ();
    test_template_suspense_boundary ();
    test_multiple_hydration_contexts_isolated ();
    test_cleanup_removes_listeners ();
    test_state_hydration ();
    test_resource_hydration ();
    test_event_replay_click ();
    test_hydration_error_context_clears ();
    test_template_reactive_text ();
    test_template_show_when ();
    test_template_bind_input ();
    test_template_auto_bool_attr ();
    set_result "PASS" "PASS"
  with exn ->
    let err_msg = exn_to_string exn in
    let stack = error_stack exn in
    (match stack with
     | None -> ()
     | Some s -> error s);
    set_result "FAIL" ~error:err_msg ?stack ("FAIL: " ^ err_msg)

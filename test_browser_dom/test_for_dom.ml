open Solid_ml_browser
open Dom

module Signal = Env.Signal
module H = Env.Html
module For = Solid_ml_browser.For

let fail msg =
  raise (Failure msg)

let assert_eq ~name a b =
  if a <> b then fail (name ^ ": expected " ^ b ^ ", got " ^ a)

let with_root f =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  f root

let render_for ~root ~items ~fallback_text () =
  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node =
        For.create
          {
            For.each = items;
            fallback =
              (match fallback_text with
               | None -> None
               | Some text -> Some (H.div ~children:[H.text text] ()));
            children =
              (fun item _index ->
                H.span ~id:("item-" ^ item) ~children:[H.text item] ());
          }
      in
      H.append_to_element root node)
  in
  dispose

let test_for_renders_initial_items () =
  with_root (fun root ->
    let items, _set_items = Signal.create [ "A"; "B" ] in
    let dispose = render_for ~root ~items ~fallback_text:None () in
    assert_eq ~name:"for initial text" (get_text_content root) "AB";
    dispose ()
  )

let test_for_updates_on_append () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B" ] in
    let dispose = render_for ~root ~items ~fallback_text:None () in
    set_items [ "A"; "B"; "C" ];
    assert_eq ~name:"for append text" (get_text_content root) "ABC";
    dispose ()
  )

let test_for_removes_items () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B"; "C" ] in
    let dispose = render_for ~root ~items ~fallback_text:None () in
    set_items [ "A" ];
    assert_eq ~name:"for remove text" (get_text_content root) "A";
    dispose ()
  )

let test_for_reorders_preserve_nodes () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B"; "C" ] in
    let dispose = render_for ~root ~items ~fallback_text:None () in
    let find id =
      match query_selector_within root ("#item-" ^ id) with
      | None -> fail ("for reorder: missing item-" ^ id)
      | Some el -> el
    in
    let a_before = find "A" in
    let b_before = find "B" in
    let c_before = find "C" in
    set_items [ "C"; "A"; "B" ];
    let ids =
      get_children root
      |> Array.to_list
      |> List.map get_id
    in
    let expected = [ "item-C"; "item-A"; "item-B" ] in
    if ids <> expected then
      fail
        ("for reorder order: expected "
        ^ String.concat "," expected
        ^ ", got "
        ^ String.concat "," ids);
    let a_after = find "A" in
    let b_after = find "B" in
    let c_after = find "C" in
    if a_before != a_after then fail "for reorder: A node replaced";
    if b_before != b_after then fail "for reorder: B node replaced";
    if c_before != c_after then fail "for reorder: C node replaced";
    assert_eq ~name:"for reorder text" (get_text_content root) "CAB";
    dispose ()
  )

let test_for_fallback_toggle () =
  with_root (fun root ->
    let items, set_items = Signal.create [] in
    let dispose = render_for ~root ~items ~fallback_text:(Some "Empty") () in
    assert_eq ~name:"for fallback initial" (get_text_content root) "Empty";
    set_items [ "A" ];
    assert_eq ~name:"for fallback removed" (get_text_content root) "A";
    set_items [];
    assert_eq ~name:"for fallback restored" (get_text_content root) "Empty";
    dispose ()
  )

let run () =
  test_for_renders_initial_items ();
  test_for_updates_on_append ();
  test_for_removes_items ();
  test_for_reorders_preserve_nodes ();
  test_for_fallback_toggle ()

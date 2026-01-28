open Solid_ml_browser
open Dom

module Signal = Env.Signal
module Effect = Env.Effect
module H = Env.Html
module Index = Solid_ml_browser.Index

let fail msg =
  raise (Failure msg)

let assert_eq ~name a b =
  if a <> b then fail (name ^ ": expected " ^ b ^ ", got " ^ a)

let with_root f =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  f root

let render_index ~root ~items ~fallback_text () =
  let (_res, dispose) =
    Reactive_core.create_root (fun () ->
      let node =
        Index.create
          {
            Index.each = items;
            fallback =
              (match fallback_text with
              | None -> None
              | Some text -> Some (H.div ~children:[H.text text] ()));
            children =
              (fun item_signal _index ->
                let value, set_value = Signal.create (item_signal ()) in
                Effect.create (fun () ->
                  let _ = Signal.get items in
                  set_value (item_signal ()));
                H.span ~children:[H.reactive_text_string value] ());
          }
      in
      H.append_to_element root node)
  in
  dispose

let test_index_renders_initial_items () =
  with_root (fun root ->
    let items, _set_items = Signal.create [ "A"; "B" ] in
    let dispose = render_index ~root ~items ~fallback_text:None () in
    assert_eq ~name:"index initial text" (get_text_content root) "AB";
    dispose ()
  )

let test_index_updates_item_by_position () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B" ] in
    let dispose = render_index ~root ~items ~fallback_text:None () in
    assert_eq ~name:"index initial update" (get_text_content root) "AB";
    set_items [ "A"; "Z" ];
    assert_eq ~name:"index update by position" (get_text_content root) "AZ";
    dispose ()
  )

let test_index_preserves_nodes_on_append () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B" ] in
    let dispose = render_index ~root ~items ~fallback_text:None () in
    let before = get_child_nodes root in
    let first_el = element_of_node before.(0) in
    let second_el = element_of_node before.(1) in
    set_items [ "A"; "B"; "C" ];
    let after = get_child_nodes root in
    let first_el_after = element_of_node after.(0) in
    let second_el_after = element_of_node after.(1) in
    if first_el != first_el_after then fail "index append: first node replaced";
    if second_el != second_el_after then fail "index append: second node replaced";
    dispose ()
  )

let test_index_removes_tail_items () =
  with_root (fun root ->
    let items, set_items = Signal.create [ "A"; "B"; "C" ] in
    let dispose = render_index ~root ~items ~fallback_text:None () in
    assert_eq ~name:"index initial shrink" (get_text_content root) "ABC";
    set_items [ "A" ];
    assert_eq ~name:"index shrink text" (get_text_content root) "A";
    dispose ()
  )

let test_index_fallback_toggle () =
  with_root (fun root ->
    let items, set_items = Signal.create [] in
    let dispose = render_index ~root ~items ~fallback_text:(Some "Empty") () in
    assert_eq ~name:"index fallback initial" (get_text_content root) "Empty";
    set_items [ "A" ];
    assert_eq ~name:"index fallback removed" (get_text_content root) "A";
    set_items [];
    assert_eq ~name:"index fallback restored" (get_text_content root) "Empty";
    dispose ()
  )

let run () =
  test_index_renders_initial_items ();
  test_index_updates_item_by_position ();
  test_index_preserves_nodes_on_append ();
  test_index_removes_tail_items ();
  test_index_fallback_toggle ()

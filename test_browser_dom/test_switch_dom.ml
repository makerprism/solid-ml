open Solid_ml_browser
open Dom

module Signal = Reactive.Signal
module Effect = Solid_ml_browser.Env.Effect
module Owner = Solid_ml_browser.Env.Owner

let fail msg =
  raise (Failure msg)

let assert_eq ~name a b =
  if a <> b then fail (name ^ ": expected " ^ b ^ ", got " ^ a)

let with_root f =
  let root = create_element (document ()) "div" in
  let body : element = [%mel.raw "document.body"] in
  append_child body (node_of_element root);
  f root

let test_switch_first_match_wins () =
  with_root (fun root ->
    let mode, set_mode = Signal.create 1 in

    let dispose =
      Render.render root (fun () ->
        Html.div
          ~children:
            [ Solid_ml_template_runtime.Tpl.switch
                ~match_:(fun () -> Signal.get mode)
                ~cases:
                  [|
                    ((fun v -> v >= 1), (fun () -> Html.text "First"));
                    ((fun v -> v = 1), (fun () -> Html.text "Second"))
                  |] ]
          ())
    in

    assert_eq ~name:"switch first match" (get_text_content root) "First";
    set_mode 1;
    assert_eq ~name:"switch still first" (get_text_content root) "First";
    dispose ()
  )

let test_switch_updates_on_signal_change () =
  with_root (fun root ->
    let mode, set_mode = Signal.create 1 in

    let dispose =
      Render.render root (fun () ->
        Html.div
          ~children:
            [ Solid_ml_template_runtime.Tpl.switch
                ~match_:(fun () -> Signal.get mode)
                ~cases:
                  [|
                    ((fun v -> v = 1), (fun () -> Html.text "One"));
                    ((fun v -> v = 2), (fun () -> Html.text "Two"));
                    ((fun _ -> true), (fun () -> Html.text "Other"))
                  |] ]
          ())
    in

    assert_eq ~name:"switch initial" (get_text_content root) "One";
    set_mode 2;
    assert_eq ~name:"switch update" (get_text_content root) "Two";
    set_mode 3;
    assert_eq ~name:"switch fallback" (get_text_content root) "Other";
    dispose ()
  )

let test_switch_reactive_branch_updates () =
  with_root (fun root ->
    let mode, set_mode = Signal.create 1 in
    let label, set_label = Signal.create "A" in

    let dispose =
      Render.render root (fun () ->
        Html.div
          ~children:
            [ Solid_ml_template_runtime.Tpl.switch
                ~match_:(fun () -> Signal.get mode)
                ~cases:
                  [|
                    ((fun v -> v = 1), (fun () -> Html.text (Signal.get label)));
                    ((fun _ -> true), (fun () -> Html.text "Other"))
                  |] ]
          ())
    in

    assert_eq ~name:"switch reactive initial" (get_text_content root) "A";
    set_label "B";
    assert_eq ~name:"switch reactive update" (get_text_content root) "B";
    set_mode 2;
    assert_eq ~name:"switch reactive fallback" (get_text_content root) "Other";
    dispose ()
  )

let test_switch_disposes_previous_branch () =
  with_root (fun root ->
    let mode, set_mode = Signal.create 1 in
    let disposed = ref 0 in

    let dispose =
      Render.render root (fun () ->
        Html.div
          ~children:
            [ Solid_ml_template_runtime.Tpl.switch
                ~match_:(fun () -> Signal.get mode)
                ~cases:
                  [|
                    ((fun v -> v = 1),
                     (fun () ->
                       Owner.on_cleanup (fun () -> disposed := !disposed + 1);
                       Html.text "One"));
                    ((fun _ -> true),
                     (fun () ->
                       Owner.on_cleanup (fun () -> disposed := !disposed + 1);
                       Html.text "Other"))
                  |] ]
          ())
    in

    assert_eq ~name:"switch dispose initial" (string_of_int !disposed) "0";
    set_mode 2;
    assert_eq ~name:"switch dispose after swap" (string_of_int !disposed) "1";
    dispose ()
  )

let test_switch_preserves_dom_for_same_case () =
  with_root (fun root ->
    let mode, set_mode = Signal.create 1 in

    let dispose =
      Render.render root (fun () ->
        Html.div
          ~children:
            [ Solid_ml_template_runtime.Tpl.switch
                ~match_:(fun () -> Signal.get mode)
                ~cases:
                  [|
                    ((fun v -> v = 1),
                     (fun () -> Html.span ~id:"a" ~children:[Html.text "A"] ()));
                    ((fun _ -> true),
                     (fun () -> Html.span ~id:"b" ~children:[Html.text "B"] ()))
                  |] ]
          ())
    in

    let node_before =
      match query_selector_within root "#a" with
      | None -> fail "switch preserve: missing #a"
      | Some el -> el
    in
    set_mode 1;
    let node_after =
      match query_selector_within root "#a" with
      | None -> fail "switch preserve: missing #a after update"
      | Some el -> el
    in
    if node_before != node_after then
      fail "switch preserve: node identity changed";
    dispose ()
  )

let run () =
  test_switch_first_match_wins ();
  test_switch_updates_on_signal_change ();
  test_switch_reactive_branch_updates ();
  test_switch_disposes_previous_branch ();
  test_switch_preserves_dom_for_same_case ()

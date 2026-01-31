module Hello (Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV) = struct
  open Env

  let render_div ~name () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_div_props ~name () =
    Html.div
      ~id:"root"
      ~class_:"c1 c2"
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_span ~name () =
    Html.span
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_p ~name () =
    Html.p
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_p_static ~name () =
    Html.p
      ~children:
        [ Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name);
          Html.text "!" ]
      ()

  let render_p_formatting ~name () =
    Html.p
      ~children:
        [ Html.text "\n  ";
          Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name);
          Html.text "!";
          Html.text "\n" ]
      ()

  let render_p_space ~name () =
    Html.p
      ~children:
        [ Html.text " ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_p_double_space ~name () =
    Html.p
      ~children:
        [ Html.text "  ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_p_tab_formatting ~name () =
    Html.p
      ~children:
        [ Html.text "\t";
          Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_pre_formatting ~name () =
    Html.pre
      ~children:
        [ Html.text "\n  ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name);
          Html.text "\n" ]
      ()

  let render_code_formatting ~name () =
    Html.code
      ~children:
        [ Html.text "\n  ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name);
          Html.text "\n" ]
      ()

  let render_p_two_slots ~first ~last () =
    Html.p
      ~children:
        [ Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get first);
          Html.text ", ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get last);
          Html.text "!" ]
      ()

  let render_div_conditional ~flag () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.show
            ~when_:(fun () -> Signal.get flag)
            (fun () -> Html.text "A") ]
      ()

  let render_div_if ~flag () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.if_
            ~when_:(fun () -> Signal.get flag)
            ~then_:(fun () -> Html.text "A")
            ~else_:(fun () -> Html.text "B") ]
      ()

  let render_div_switch ~step () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.switch
            ~match_:(fun () -> Signal.get step)
            ~cases:
              [| ((fun v -> v = 1), (fun () -> Html.text "One"));
                 ((fun v -> v = 2), (fun () -> Html.text "Two"))
              |] ]
      ()

  let render_div_adjacent_show ~first ~second () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.show
            ~when_:(fun () -> Signal.get first)
            (fun () -> Html.text "A");
          Solid_ml_template_runtime.Tpl.show
            ~when_:(fun () -> Signal.get second)
            (fun () -> Html.text "B") ]
      ()

  let render_div_adjacent_nodes () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.nodes (fun () -> Html.text "A");
          Solid_ml_template_runtime.Tpl.nodes (fun () -> Html.text "B") ]
      ()

  let render_div_each ~items () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.each
            ~items:(fun () -> Signal.get items)
            ~render:(fun item ->
              Html.span
                ~children:
                  [ Html.text item ]
                ()) ]
      ()

  let render_div_eachi ~items () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.eachi
            ~items:(fun () -> Signal.get items)
            ~render:(fun idx item ->
              Html.span
                ~children:
                  [ Html.text (string_of_int idx ^ ":" ^ item) ]
                ()) ]
      ()

  let render_div_each_indexed ~items () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.each_indexed
            ~items:(fun () -> Signal.get items)
            ~render:(fun ~index ~item ->
              Html.span
                ~children:
                  [ Html.text (string_of_int (index ()) ^ ":" ^ item ()) ]
                ()) ]
      ()

  let render_div_style ~styles () =
    Html.div
      ~style:(Solid_ml_template_runtime.Tpl.style (fun () -> Signal.get styles))
      ~children:[ Html.text "Styled" ]
      ()

  let render_div_spread ~spread () =
    Html.div
      ~attrs:(Solid_ml_template_runtime.Tpl.spread (fun () -> Signal.get spread))
      ~children:[ Html.text "Spread" ]
      ()

  let render_div_dynamic ~flag () =
    let comp_a label =
      Html.span ~children:[ Html.text label ] ()
    in
    let comp_b label =
      Html.em ~children:[ Html.text label ] ()
    in
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.dynamic
            ~component:(fun () -> if Signal.get flag then comp_a else comp_b)
            ~props:(fun () -> "Hi") ]
      ()

  let render_div_portal () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.portal
            ~render:(fun () -> Html.text "Portaled") ]
      ()

  let render_div_suspense_list () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.suspense_list
            ~render:(fun () -> Html.text "List") ]
      ()

  let render_div_deferred () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.deferred
            ~render:(fun () -> Html.text "Deferred") ]
      ()

  let render_div_transition () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.transition
            ~render:(fun () -> Html.text "Transition") ]
      ()

  let render_div_suspense () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.suspense
            ~fallback:(fun () -> Html.text "Loading")
            ~render:(fun () -> Html.text "Ready") ]
      ()

  let render_div_error_boundary () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.error_boundary
            ~fallback:(fun ~error:_ ~reset:_ -> Html.text "Error")
            ~render:(fun () -> failwith "boom") ]
      ()

  (* Simulates MLX formatting whitespace around nested intrinsic tags.
     The outer <div> should be compiled so that formatting whitespace is ignored,
     even though it contains a nested <a>. *)
  let render_div_nested_formatting ~href ~label () =
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

let count_substring (s : string) (needle : string) : int =
  let rec loop acc i =
    match String.index_from_opt s i needle.[0] with
    | None -> acc
    | Some j ->
      if j + String.length needle <= String.length s
         && String.sub s j (String.length needle) = needle
      then loop (acc + 1) (j + String.length needle)
      else loop acc (j + 1)
  in
  if needle = "" then invalid_arg "count_substring: empty needle";
  loop 0 0

let () =
  print_endline "Test: Template PPX compiles Tpl.text (non-MLX)";
  let html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div ~name ())
  in
  assert (html = "<div><!--#-->World<!--#--></div>");

  let html_props =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_props ~name ())
  in
  assert (html_props = "<div id=\"root\" class=\"c1 c2\"><!--#-->World<!--#--></div>");

  let html_span =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_span ~name ())
  in
  assert (html_span = "<span><!--#-->World<!--#--></span>");

  let html_p =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p ~name ())
  in
  assert (html_p = "<p><!--#-->World<!--#--></p>");

  let html_p_static =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_static ~name ())
  in
  assert (html_p_static = "<p>Hello <!--#-->World<!--#-->!</p>");
  assert (count_substring html_p_static "<!--#-->" = 2);

  let html_p_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_formatting ~name ())
  in
  assert (html_p_formatting = "<p>Hello <!--#-->World<!--#-->!</p>");

  let html_p_space =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_space ~name ())
  in
  assert (html_p_space = "<p> <!--#-->World<!--#--></p>");

  let html_p_double_space =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_double_space ~name ())
  in
  assert (html_p_double_space = "<p>  <!--#-->World<!--#--></p>");

  let html_p_tab_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_tab_formatting ~name ())
  in
  assert (html_p_tab_formatting = "<p>Hello <!--#-->World<!--#--></p>");

  let html_pre_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_pre_formatting ~name ())
  in
  assert (html_pre_formatting = "<pre>\n  <!--#-->World<!--#-->\n</pre>");

  let html_code_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_code_formatting ~name ())
  in
  assert (html_code_formatting = "<code>\n  <!--#-->World<!--#-->\n</code>");

  let html_p_two =
    Solid_ml_ssr.Render.to_string (fun () ->
      let first, _set_first = Solid_ml_ssr.Env.Signal.create "Ada" in
      let last, _set_last = Solid_ml_ssr.Env.Signal.create "Lovelace" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_two_slots ~first ~last ())
  in
  assert (html_p_two = "<p>Hello <!--#-->Ada<!--#-->, <!--#-->Lovelace<!--#-->!</p>");
  assert (count_substring html_p_two "<!--#-->" = 4);

  let html_nested =
    Solid_ml_ssr.Render.to_string (fun () ->
      let href, _set_href = Solid_ml_ssr.Env.Signal.create "/a" in
      let label, _set_label = Solid_ml_ssr.Env.Signal.create "Link" in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_nested_formatting ~href ~label ())
  in
  assert (html_nested = "<div><a href=\"/a\"><!--#-->Link<!--#--></a></div>");

  let html_cond_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag, _set_flag = Solid_ml_ssr.Env.Signal.create true in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_conditional ~flag ())
  in
  assert (html_cond_true = "<div><!--$-->A<!--$--></div>");

  let html_if_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag, _set_flag = Solid_ml_ssr.Env.Signal.create true in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_if ~flag ())
  in
  assert (html_if_true = "<div><!--$-->A<!--$--></div>");

  let html_if_false =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag_false, _set_flag_false = Solid_ml_ssr.Env.Signal.create false in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_if ~flag:flag_false ())
  in
  assert (html_if_false = "<div><!--$-->B<!--$--></div>");

  let html_switch =
    Solid_ml_ssr.Render.to_string (fun () ->
      let step, _set_step = Solid_ml_ssr.Env.Signal.create 2 in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_switch ~step ())
  in
  assert (html_switch = "<div><!--$-->Two<!--$--></div>");

  let html_adjacent_show =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag_a, _set_flag_a = Solid_ml_ssr.Env.Signal.create true in
      let flag_b, _set_flag_b = Solid_ml_ssr.Env.Signal.create true in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_adjacent_show ~first:flag_a ~second:flag_b ())
  in
  assert (html_adjacent_show = "<div><!--$-->A<!--$--><!--$-->B<!--$--></div>");

  let html_adjacent_nodes =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_adjacent_nodes ())
  in
  assert (html_adjacent_nodes = "<div><!--$-->A<!--$--><!--$-->B<!--$--></div>");

  let html_each =
    Solid_ml_ssr.Render.to_string (fun () ->
      let items, _set_items = Solid_ml_ssr.Env.Signal.create [ "a"; "b" ] in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_each ~items ())
  in
  let expected_each =
    "<div><!--$--><!--k:30--><span><!--#-->a<!--#--></span><!--/k--><!--k:31--><span><!--#-->b<!--#--></span><!--/k--><!--$--></div>"
  in
  if html_each <> expected_each then
    failwith ("each mismatch: " ^ html_each);

  let html_eachi =
    Solid_ml_ssr.Render.to_string (fun () ->
      let items_i, _set_items_i = Solid_ml_ssr.Env.Signal.create [ "x"; "y" ] in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_eachi ~items:items_i ())
  in
  let expected_eachi =
    "<div><!--$--><!--k:30--><span><!--#-->0:x<!--#--></span><!--/k--><!--k:31--><span><!--#-->1:y<!--#--></span><!--/k--><!--$--></div>"
  in
  if html_eachi <> expected_eachi then
    failwith ("eachi mismatch: " ^ html_eachi);

  let html_each_indexed =
    Solid_ml_ssr.Render.to_string (fun () ->
      let items_idx, _set_items_idx = Solid_ml_ssr.Env.Signal.create [ "u"; "v" ] in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_each_indexed ~items:items_idx ())
  in
  let expected_each_indexed =
    "<div><!--$--><!--k:30--><span><!--#-->0:u<!--#--></span><!--/k--><!--k:31--><span><!--#-->1:v<!--#--></span><!--/k--><!--$--></div>"
  in
  if html_each_indexed <> expected_each_indexed then
    failwith ("each_indexed mismatch: " ^ html_each_indexed);

  let html_style =
    Solid_ml_ssr.Render.to_string (fun () ->
      let styles, _set_styles = Solid_ml_ssr.Env.Signal.create [ ("color", Some "red") ] in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_style ~styles ())
  in
  assert (html_style = "<div style=\"color:red\">Styled</div>");

  let spread_value =
    Solid_ml_template_runtime.Spread.attrs [ ("data-x", Some "1") ]
  in
  let html_spread =
    Solid_ml_ssr.Render.to_string (fun () ->
      let spread, _set_spread = Solid_ml_ssr.Env.Signal.create spread_value in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_spread ~spread ())
  in
  assert (html_spread = "<div data-x=\"1\">Spread</div>");

  let html_dynamic_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag_true, _set_flag_true = Solid_ml_ssr.Env.Signal.create true in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_dynamic ~flag:flag_true ())
  in
  assert (html_dynamic_true = "<div><!--$--><span><!--#-->Hi<!--#--></span><!--$--></div>");

  let html_dynamic_false =
    Solid_ml_ssr.Render.to_string (fun () ->
      let flag_false, _set_flag_false = Solid_ml_ssr.Env.Signal.create false in
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_dynamic ~flag:flag_false ())
  in
  assert (html_dynamic_false = "<div><!--$--><em><!--#-->Hi<!--#--></em><!--$--></div>");

  let html_portal =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_portal ())
  in
  assert (html_portal = "<div><!--$-->Portaled<!--$--></div>");

  let html_suspense_list =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_suspense_list ())
  in
  assert (html_suspense_list = "<div><!--$-->List<!--$--></div>");

  let html_deferred =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_deferred ())
  in
  assert (html_deferred = "<div><!--$-->Deferred<!--$--></div>");

  let html_transition =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_transition ())
  in
  assert (html_transition = "<div><!--$-->Transition<!--$--></div>");

  let html_suspense =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_suspense ())
  in
  assert (html_suspense = "<div><!--$-->Ready<!--$--></div>");

  let html_error_boundary =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_error_boundary ())
  in
  assert (html_error_boundary = "<div><!--$-->Error<!--$--></div>");

  print_endline "  PASSED"

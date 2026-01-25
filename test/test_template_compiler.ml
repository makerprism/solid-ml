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
  let name, _set_name = Solid_ml_ssr.Env.Signal.create "World" in
  let html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div ~name ())
  in
  assert (html = "<div><!--#-->World<!--#--></div>");

  let html_props =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_props ~name ())
  in
  assert (html_props = "<div id=\"root\" class=\"c1 c2\"><!--#-->World<!--#--></div>");

  let html_span =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_span ~name ())
  in
  assert (html_span = "<span><!--#-->World<!--#--></span>");

  let html_p =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p ~name ())
  in
  assert (html_p = "<p><!--#-->World<!--#--></p>");

  let html_p_static =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_static ~name ())
  in
  assert (html_p_static = "<p>Hello <!--#-->World<!--#-->!</p>");
  assert (count_substring html_p_static "<!--#-->" = 2);

  let html_p_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_formatting ~name ())
  in
  assert (html_p_formatting = "<p>Hello <!--#-->World<!--#-->!</p>");

  let html_p_space =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_space ~name ())
  in
  assert (html_p_space = "<p> <!--#-->World<!--#--></p>");

  let html_p_double_space =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_double_space ~name ())
  in
  assert (html_p_double_space = "<p>  <!--#-->World<!--#--></p>");

  let html_p_tab_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_tab_formatting ~name ())
  in
  assert (html_p_tab_formatting = "<p>Hello <!--#-->World<!--#--></p>");

  let html_pre_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_pre_formatting ~name ())
  in
  assert (html_pre_formatting = "<pre>\n  <!--#-->World<!--#-->\n</pre>");

  let html_code_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_code_formatting ~name ())
  in
  assert (html_code_formatting = "<code>\n  <!--#-->World<!--#-->\n</code>");

  let first, _set_first = Solid_ml_ssr.Env.Signal.create "Ada" in
  let last, _set_last = Solid_ml_ssr.Env.Signal.create "Lovelace" in
  let html_p_two =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_two_slots ~first ~last ())
  in
  assert (html_p_two = "<p>Hello <!--#-->Ada<!--#-->, <!--#-->Lovelace<!--#-->!</p>");
  assert (count_substring html_p_two "<!--#-->" = 4);

  let href, _set_href = Solid_ml_ssr.Env.Signal.create "/a" in
  let label, _set_label = Solid_ml_ssr.Env.Signal.create "Link" in
  let html_nested =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_nested_formatting ~href ~label ())
  in
  assert (html_nested = "<div><a href=\"/a\"><!--#-->Link<!--#--></a></div>");

  let flag, _set_flag = Solid_ml_ssr.Env.Signal.create true in
  let html_cond_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_conditional ~flag ())
  in
  assert (html_cond_true = "<div><!--$-->A<!--$--></div>");

  let html_if_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_if ~flag ())
  in
  assert (html_if_true = "<div><!--$-->A<!--$--></div>");

  let flag_false, _set_flag_false = Solid_ml_ssr.Env.Signal.create false in
  let html_if_false =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_if ~flag:flag_false ())
  in
  assert (html_if_false = "<div><!--$-->B<!--$--></div>");

  let step, _set_step = Solid_ml_ssr.Env.Signal.create 2 in
  let html_switch =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_switch ~step ())
  in
  assert (html_switch = "<div><!--$-->Two<!--$--></div>");

  let items, _set_items = Solid_ml_ssr.Env.Signal.create [ "a"; "b" ] in
  let html_each =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_each ~items ())
  in
  let expected_each =
    "<div><!--$--><!--k:30--><span>a</span><!--/k--><!--k:31--><span>b</span><!--/k--><!--$--></div>"
  in
  if html_each <> expected_each then
    failwith ("each mismatch: " ^ html_each);

  let items_i, _set_items_i = Solid_ml_ssr.Env.Signal.create [ "x"; "y" ] in
  let html_eachi =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_eachi ~items:items_i ())
  in
  let expected_eachi =
    "<div><!--$--><!--k:30--><span>0:x</span><!--/k--><!--k:31--><span>1:y</span><!--/k--><!--$--></div>"
  in
  if html_eachi <> expected_eachi then
    failwith ("eachi mismatch: " ^ html_eachi);

  let items_idx, _set_items_idx = Solid_ml_ssr.Env.Signal.create [ "u"; "v" ] in
  let html_each_indexed =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_each_indexed ~items:items_idx ())
  in
  let expected_each_indexed =
    "<div><!--$--><!--k:30--><span><!--#-->0:u<!--#--></span><!--/k--><!--k:31--><span><!--#-->1:v<!--#--></span><!--/k--><!--$--></div>"
  in
  if html_each_indexed <> expected_each_indexed then
    failwith ("each_indexed mismatch: " ^ html_each_indexed);

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

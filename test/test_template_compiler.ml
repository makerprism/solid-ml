open Solid_ml

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
  let name, _set_name = Signal.create "World" in
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

  let first, _set_first = Signal.create "Ada" in
  let last, _set_last = Signal.create "Lovelace" in
  let html_p_two =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_two_slots ~first ~last ())
  in
  assert (html_p_two = "<p>Hello <!--#-->Ada<!--#-->, <!--#-->Lovelace<!--#-->!</p>");
  assert (count_substring html_p_two "<!--#-->" = 4);

  let href, _set_href = Signal.create "/a" in
  let label, _set_label = Signal.create "Link" in
  let html_nested =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_nested_formatting ~href ~label ())
  in
  assert (html_nested = "<div><a href=\"/a\"><!--#-->Link<!--#--></a></div>");

  let flag, _set_flag = Signal.create true in
  let html_cond_true =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div_conditional ~flag ())
  in
  assert (html_cond_true = "<div><!--$-->A<!--$--></div>");

  print_endline "  PASSED"

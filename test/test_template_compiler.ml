open Solid_ml

module Hello (Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV) = struct
  open Env

  let render_div ~name () =
    Html.div
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

  let render_p_two_slots ~first ~last () =
    Html.p
      ~children:
        [ Html.text "Hello ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get first);
          Html.text ", ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get last);
          Html.text "!" ]
      ()
end

let () =
  print_endline "Test: Template PPX compiles Tpl.text (non-MLX)";
  let name, _set_name = Signal.create "World" in
  let html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_div ~name ())
  in
  assert (html = "<div>World</div>");

  let html_span =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_span ~name ())
  in
  assert (html_span = "<span>World</span>");

  let html_p =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p ~name ())
  in
  assert (html_p = "<p>World</p>");

  let html_p_static =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_static ~name ())
  in
  assert (html_p_static = "<p>Hello World!</p>");

  let html_p_formatting =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_formatting ~name ())
  in
  assert (html_p_formatting = "<p>Hello World!</p>");

  let html_p_space =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_space ~name ())
  in
  assert (html_p_space = "<p> World</p>");

  let first, _set_first = Signal.create "Ada" in
  let last, _set_last = Signal.create "Lovelace" in
  let html_p_two =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module C = Hello (Solid_ml_ssr.Env) in
      C.render_p_two_slots ~first ~last ())
  in
  assert (html_p_two = "<p>Hello Ada, Lovelace!</p>");

  print_endline "  PASSED"

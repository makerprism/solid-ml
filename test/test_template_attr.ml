open Solid_ml

module C (Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV) = struct
  open Env

  let render_a_some ~name () =
    Html.a
      ~href:
        (Solid_ml_template_runtime.Tpl.attr_opt
           ~name:"href"
           (fun () -> Some "/x?y=<z>"))
      ~children:
        [ Html.text "Go ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_a_none ~name () =
    Html.a
      ~href:
        (Solid_ml_template_runtime.Tpl.attr_opt
           ~name:"href"
           (fun () -> None))
      ~children:
        [ Html.text "Go ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_a_attr ~href ~name () =
    Html.a
      ~href:
        (Solid_ml_template_runtime.Tpl.attr
           ~name:"href"
           (fun () -> Signal.get href))
      ~children:
        [ Html.text "Go ";
          Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get name) ]
      ()

  let render_div_prefix_then_link ~prefix ~href ~label () =
    Html.div
      ~children:
        [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get prefix);
          Html.a
            ~href:
              (Solid_ml_template_runtime.Tpl.attr
                 ~name:"href"
                 (fun () -> Signal.get href))
            ~children:
              [ Solid_ml_template_runtime.Tpl.text (fun () -> Signal.get label) ]
            () ]
      ()
end

let () =
  print_endline "Test: Template PPX compiles Tpl.attr_opt";
  let name, _set_name = Signal.create "World" in

  let some_html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      R.render_a_some ~name ())
  in
  assert (some_html = "<a href=\"/x?y=&lt;z&gt;\">Go <!--#-->World<!--#--></a>");

  let none_html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      R.render_a_none ~name ())
  in
  assert (none_html = "<a>Go <!--#-->World<!--#--></a>");

  let href, _set_href = Signal.create "/x?y=<z>" in
  let attr_html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      R.render_a_attr ~href ~name ())
  in
  assert (attr_html = "<a href=\"/x?y=&lt;z&gt;\">Go <!--#-->World<!--#--></a>");

  let empty_href, _set_empty_href = Signal.create "" in
  let empty_html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      R.render_a_attr ~href:empty_href ~name ())
  in
  assert (empty_html = "<a href=\"\">Go <!--#-->World<!--#--></a>");

  let nested_html =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      Solid_ml_ssr.Html.div ~children:[ R.render_a_some ~name () ] ())
  in
  assert (nested_html = "<div><a href=\"/x?y=&lt;z&gt;\">Go <!--#-->World<!--#--></a></div>");

  (* Regression: nested element paths must remain stable even when a preceding
     text slot renders an empty string on SSR. *)
  let prefix, _set_prefix = Signal.create "" in
  let href2, _set_href2 = Signal.create "/p" in
  let label2, _set_label2 = Signal.create "X" in
  let nested_after_empty_text =
    Solid_ml_ssr.Render.to_string (fun () ->
      let module R = C (Solid_ml_ssr.Env) in
      R.render_div_prefix_then_link ~prefix ~href:href2 ~label:label2 ())
  in
  assert (nested_after_empty_text = "<div><!--#--><!--#--><a href=\"/p\"><!--#-->X<!--#--></a></div>");

  print_endline "  PASSED"

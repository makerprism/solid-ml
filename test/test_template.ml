module Html = Solid_ml_ssr.Html

let test_template_text_slot () =
  print_endline "Test: Template text slot renders without markers";
  let template =
    Html.Template.compile
      ~segments:[| "<div>"; "</div>" |]
      ~slot_kinds:[| `Text |]
  in
  let inst = Html.Template.instantiate template in
  let slot = Html.Template.bind_text inst ~id:0 ~path:[| 0 |] in
  Html.Template.set_text slot "Hello";
  let html = Html.to_string (Html.Template.root inst) in
  assert (html = "<div>Hello</div>");
  print_endline "  PASSED"

let test_template_attr_slot () =
  print_endline "Test: Template attr slot interpolates escaped value";
  let template =
    Html.Template.compile
      ~segments:[| "<a href=\""; "\">x</a>" |]
      ~slot_kinds:[| `Attr |]
  in
  let inst = Html.Template.instantiate template in
  let slot = Html.Template.bind_text inst ~id:0 ~path:[| 0 |] in
  Html.Template.set_text slot "https://example.com?q=<tag>";
  let html = Html.to_string (Html.Template.root inst) in
  assert (html = "<a href=\"https://example.com?q=&lt;tag&gt;\">x</a>");
  print_endline "  PASSED"

let test_template_multi_slot () =
  print_endline "Test: Template supports multiple slots";
  let template =
    Html.Template.compile
      ~segments:[| "<div><span>"; "</span><a href=\""; "\">"; "</a></div>" |]
      ~slot_kinds:[| `Text; `Attr; `Text |]
  in
  let inst = Html.Template.instantiate template in
  let slot0 = Html.Template.bind_text inst ~id:0 ~path:[| 0 |] in
  let slot1 = Html.Template.bind_text inst ~id:1 ~path:[| 0 |] in
  let slot2 = Html.Template.bind_text inst ~id:2 ~path:[| 0 |] in
  Html.Template.set_text slot0 "Hello";
  Html.Template.set_text slot1 "/path?q=<tag>";
  Html.Template.set_text slot2 "Link";
  let html = Html.to_string (Html.Template.root inst) in
  assert (html = "<div><span>Hello</span><a href=\"/path?q=&lt;tag&gt;\">Link</a></div>");
  print_endline "  PASSED"

let () =
  test_template_text_slot ();
  test_template_attr_slot ();
  test_template_multi_slot ();
  print_endline "All template tests passed!";
  ()

(** Tests for solid-ml-html server-side rendering *)

open Solid_ml_html

(** Helper to check if string contains substring *)
let contains s sub =
  let len = String.length sub in
  let rec check i =
    if i + len > String.length s then false
    else if String.sub s i len = sub then true
    else check (i + 1)
  in
  check 0

(* ============ HTML Element Tests ============ *)

let test_text () =
  print_endline "Test: Text nodes are escaped";
  let node = Html.text "<script>alert('xss')</script>" in
  let html = Html.to_string node in
  assert (html = "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;");
  print_endline "  PASSED"

let test_raw () =
  print_endline "Test: Raw nodes are not escaped";
  let node = Html.raw "<script>valid();</script>" in
  let html = Html.to_string node in
  assert (html = "<script>valid();</script>");
  print_endline "  PASSED"

let test_int_text () =
  print_endline "Test: Int to text";
  let node = Html.int 42 in
  let html = Html.to_string node in
  assert (html = "42");
  print_endline "  PASSED"

let test_simple_element () =
  print_endline "Test: Simple element";
  let node = Html.(div ~children:[text "Hello"] ()) in
  let html = Html.to_string node in
  assert (html = "<div>Hello</div>");
  print_endline "  PASSED"

let test_element_with_attrs () =
  print_endline "Test: Element with attributes";
  let node = Html.(div ~id:"main" ~class_:"container" ~children:[text "Content"] ()) in
  let html = Html.to_string node in
  assert (String.sub html 0 4 = "<div");
  assert (contains html "id=\"main\"");
  assert (contains html "class=\"container\"");
  assert (contains html ">Content</div>");
  print_endline "  PASSED"

let test_nested_elements () =
  print_endline "Test: Nested elements";
  let node = Html.(
    div ~class_:"outer" ~children:[
      p ~children:[text "Paragraph 1"] ();
      p ~children:[text "Paragraph 2"] ()
    ] ()
  ) in
  let html = Html.to_string node in
  assert (contains html "<p>Paragraph 1</p>");
  assert (contains html "<p>Paragraph 2</p>");
  assert (contains html "class=\"outer\"");
  print_endline "  PASSED"

let test_self_closing () =
  print_endline "Test: Self-closing elements";
  let node = Html.(br ()) in
  let html = Html.to_string node in
  assert (html = "<br />");
  print_endline "  PASSED"

let test_input () =
  print_endline "Test: Input element";
  let node = Html.(input ~type_:"text" ~name:"email" ~placeholder:"Enter email" ~required:true ()) in
  let html = Html.to_string node in
  assert (String.sub html 0 6 = "<input");
  assert (contains html "type=\"text\"");
  assert (contains html "name=\"email\"");
  assert (contains html "required");
  print_endline "  PASSED"

let test_attribute_escaping () =
  print_endline "Test: Attribute values are escaped";
  let node = Html.(div ~id:"test\"value" ~children:[] ()) in
  let html = Html.to_string node in
  assert (contains html "test&quot;value");
  print_endline "  PASSED"

let test_fragment () =
  print_endline "Test: Fragment renders children only";
  let node = Html.(fragment [
    p ~children:[text "One"] ();
    p ~children:[text "Two"] ()
  ]) in
  let html = Html.to_string node in
  assert (html = "<p>One</p><p>Two</p>");
  print_endline "  PASSED"

let test_boolean_attrs () =
  print_endline "Test: Boolean attributes";
  let node = Html.(input ~type_:"checkbox" ~checked:true ~disabled:true ()) in
  let html = Html.to_string node in
  assert (contains html "checked");
  assert (contains html "disabled");
  print_endline "  PASSED"

let test_headings () =
  print_endline "Test: Heading elements";
  let h1 = Html.(h1 ~children:[text "Title"] ()) in
  let h2 = Html.(h2 ~class_:"subtitle" ~children:[text "Subtitle"] ()) in
  assert (Html.to_string h1 = "<h1>Title</h1>");
  assert (contains (Html.to_string h2) "class=\"subtitle\"");
  assert (contains (Html.to_string h2) ">Subtitle</h2>");
  print_endline "  PASSED"

let test_link () =
  print_endline "Test: Anchor element";
  let node = Html.(a ~href:"https://example.com" ~target:"_blank" ~children:[text "Link"] ()) in
  let html = Html.to_string node in
  assert (contains html "href=\"https://example.com\"");
  assert (contains html "target=\"_blank\"");
  assert (contains html ">Link</a>");
  print_endline "  PASSED"

let test_list () =
  print_endline "Test: List elements";
  let node = Html.(ul ~children:[
    li ~children:[text "Item 1"] ();
    li ~children:[text "Item 2"] ()
  ] ()) in
  let html = Html.to_string node in
  assert (html = "<ul><li>Item 1</li><li>Item 2</li></ul>");
  print_endline "  PASSED"

let test_table () =
  print_endline "Test: Table elements";
  let node = Html.(table ~children:[
    thead ~children:[
      tr ~children:[
        th ~children:[text "Name"] ();
        th ~children:[text "Value"] ()
      ] ()
    ] ();
    tbody ~children:[
      tr ~children:[
        td ~children:[text "Foo"] ();
        td ~children:[text "Bar"] ()
      ] ()
    ] ()
  ] ()) in
  let html = Html.to_string node in
  assert (contains html "<table>");
  assert (contains html "</table>");
  assert (contains html "<th>Name</th>");
  assert (contains html "<td>Foo</td>");
  print_endline "  PASSED"

let test_form () =
  print_endline "Test: Form elements";
  let node = Html.(form ~action:"/submit" ~method_:"POST" ~children:[
    label ~for_:"name" ~children:[text "Name:"] ();
    input ~id:"name" ~name:"name" ~type_:"text" ();
    button ~type_:"submit" ~children:[text "Submit"] ()
  ] ()) in
  let html = Html.to_string node in
  assert (contains html "<form");
  assert (contains html "action=\"/submit\"");
  assert (contains html "method=\"POST\"");
  assert (contains html "<label");
  assert (contains html "<button");
  print_endline "  PASSED"

let test_img () =
  print_endline "Test: Image element";
  let node = Html.(img ~src:"/logo.png" ~alt:"Logo" ~width:100 ~height:50 ()) in
  let html = Html.to_string node in
  assert (contains html "<img");
  assert (contains html "src=\"/logo.png\"");
  assert (contains html "alt=\"Logo\"");
  print_endline "  PASSED"

(* ============ Render Tests ============ *)

let test_render_to_string () =
  print_endline "Test: Render.to_string";
  let html = Render.to_string (fun () ->
    Html.(div ~children:[text "Hello, World!"] ())
  ) in
  assert (html = "<div>Hello, World!</div>");
  print_endline "  PASSED"

let test_render_to_document () =
  print_endline "Test: Render.to_document";
  let html = Render.to_document (fun () ->
    Html.(html ~lang:"en" ~children:[
      head ~children:[
        title ~children:[text "Test"] ()
      ] ();
      body ~children:[
        div ~children:[text "Content"] ()
      ] ()
    ] ())
  ) in
  assert (String.sub html 0 15 = "<!DOCTYPE html>");
  assert (contains html "<html");
  assert (contains html "</html>");
  print_endline "  PASSED"

let test_render_with_signals () =
  print_endline "Test: Render with signals";
  let count, _set_count = Solid_ml.Signal.create 42 in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[
      text "Count: ";
      signal_text count
    ] ())
  ) in
  (* Should contain the hydration marker and value *)
  assert (contains html "42");
  print_endline "  PASSED"

let test_hydration_script () =
  print_endline "Test: Hydration script";
  let _ = Render.to_string (fun () ->
    Html.(div ~children:[text "Hello"] ())
  ) in
  let script = Render.get_hydration_script () in
  assert (contains script "<script>");
  assert (contains script "</script>");
  print_endline "  PASSED"

(* ============ Complex Examples ============ *)

let test_counter_component () =
  print_endline "Test: Counter component renders";
  let count, _set_count = Solid_ml.Signal.create 0 in
  let html = Render.to_string (fun () ->
    Html.(div ~class_:"counter" ~children:[
      p ~children:[text "Count: "; signal_text count] ();
      button ~children:[text "Increment"] ()
    ] ())
  ) in
  assert (contains html "class=\"counter\"");
  assert (contains html "<button>Increment</button>");
  print_endline "  PASSED"

let test_full_page () =
  print_endline "Test: Full page render";
  let html = Render.to_document (fun () ->
    Html.(html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"UTF-8" ();
        title ~children:[text "My App"] ();
        link ~rel:"stylesheet" ~href:"/styles.css" ()
      ] ();
      body ~id:"app" ~children:[
        header ~children:[
          nav ~children:[
            a ~href:"/" ~children:[text "Home"] ();
            a ~href:"/about" ~children:[text "About"] ()
          ] ()
        ] ();
        main ~children:[
          h1 ~children:[text "Welcome"] ();
          p ~children:[text "This is a server-rendered page."] ()
        ] ();
        footer ~children:[
          p ~children:[text "Copyright 2026"] ()
        ] ();
        script ~src:"/app.js" ~defer:true ~children:[] ()
      ] ()
    ] ())
  ) in
  assert (String.sub html 0 15 = "<!DOCTYPE html>");
  assert (contains html "lang=\"en\"");
  assert (contains html "<title>My App</title>");
  assert (contains html "<h1>Welcome</h1>");
  print_endline "  PASSED"

(* ============ Main ============ *)

let () =
  print_endline "\n=== solid-ml-html Tests ===\n";
  
  print_endline "-- HTML Element Tests --";
  test_text ();
  test_raw ();
  test_int_text ();
  test_simple_element ();
  test_element_with_attrs ();
  test_nested_elements ();
  test_self_closing ();
  test_input ();
  test_attribute_escaping ();
  test_fragment ();
  test_boolean_attrs ();
  test_headings ();
  test_link ();
  test_list ();
  test_table ();
  test_form ();
  test_img ();
  
  print_endline "\n-- Render Tests --";
  test_render_to_string ();
  test_render_to_document ();
  test_render_with_signals ();
  test_hydration_script ();
  
  print_endline "\n-- Complex Examples --";
  test_counter_component ();
  test_full_page ();
  
  print_endline "\n=== All tests passed! ===\n"

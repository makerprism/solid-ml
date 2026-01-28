(** Tests for solid-ml-html server-side rendering *)

open Solid_ml_ssr

module Signal = Solid_ml.Signal.Unsafe

(** Helper to check if string contains substring *)
let contains s sub =
  let len = String.length sub in
  let rec check i =
    if i + len > String.length s then false
    else if String.sub s i len = sub then true
    else check (i + 1)
  in
  check 0

let find_index s sub =
  let len = String.length sub in
  let rec check i =
    if i + len > String.length s then None
    else if String.sub s i len = sub then Some i
    else check (i + 1)
  in
  check 0

let require_index name value =
  match value with
  | Some idx -> idx
  | None -> failwith (name ^ " not found")

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
  let count, _set_count = Signal.create 42 in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[
      text "Count: ";
      reactive_text count
    ] ())
  ) in
  (* Should contain the hydration marker and value *)
  assert (contains html "42");
  print_endline "  PASSED"

let test_hydration_script () =
  print_endline "Test: Hydration script";
  let script =
    Solid_ml.Runtime.run (fun () ->
      Solid_ml_ssr.State.reset ();
      Solid_ml_ssr.State.set_encoded
        ~key:"count"
        ~encode:Solid_ml_ssr.State.encode_int
        3;
      let resource = Solid_ml.Resource.of_value 7 in
      Solid_ml_ssr.Resource_state.set
        ~key:"resource"
        ~encode:Solid_ml_ssr.State.encode_int
        resource;
      Render.get_hydration_script ())
  in
  assert (contains script "<script>");
  assert (contains script "</script>");
  assert (contains script "\"count\"");
  assert (contains script "3");
  assert (contains script "__SOLID_ML_EVENT_REPLAY__");
  assert (contains script "\"resource\"");
  assert (contains script "\"status\"");
  print_endline "  PASSED"

(* ============ Reactive Text Tests ============ *)

let test_reactive_text () =
  print_endline "Test: reactive_text renders int signal with hydration markers";
  let count, _set_count = Signal.create 42 in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[reactive_text count] ())
  ) in
  (* Should contain hydration markers and the value *)
  assert (contains html "<!--hk:");
  assert (contains html "42");
  assert (contains html "<!--/hk-->");
  print_endline "  PASSED"

let test_reactive_text_of () =
  print_endline "Test: reactive_text_of with custom formatter";
  let value_signal, _set_data = Signal.create {|hello|} in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[
      reactive_text_of String.uppercase_ascii value_signal
    ] ())
  ) in
  assert (contains html "HELLO");
  assert (contains html "<!--hk:");
  print_endline "  PASSED"

let test_reactive_text_string () =
  print_endline "Test: reactive_text_string renders string signal";
  let msg, _set_msg = Signal.create "world" in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[reactive_text_string msg] ())
  ) in
  assert (contains html "world");
  assert (contains html "<!--hk:");
  print_endline "  PASSED"

let test_reactive_text_marker_sequence () =
  print_endline "Test: reactive_text_string markers wrap text";
  let msg, _set_msg = Signal.create "world" in
  let html = Render.to_string (fun () ->
    Html.(div ~children:[reactive_text_string msg] ())
  ) in
  let open_idx = require_index "open marker" (find_index html "<!--hk:") in
  let value_idx = require_index "value" (find_index html "world") in
  let close_idx = require_index "close marker" (find_index html "<!--/hk-->") in
  assert (open_idx < value_idx && value_idx < close_idx);
  print_endline "  PASSED"

(* ============ Event Handler Tests ============ *)

let test_onclick_ignored () =
  print_endline "Test: onclick param is accepted and ignored on SSR";
  let handler : Html.event -> unit = fun _ -> () in
  let html = Html.to_string (
    Html.(div ~onclick:handler ~children:[text "Click me"] ())
  ) in
  (* Should render div without onclick attribute *)
  assert (html = "<div>Click me</div>");
  print_endline "  PASSED"

let test_button_onclick_ignored () =
  print_endline "Test: button onclick is ignored on SSR";
  let handler : Html.event -> unit = fun _ -> () in
  let html = Html.to_string (
    Html.(button ~onclick:handler ~children:[text "Submit"] ())
  ) in
  assert (html = "<button>Submit</button>");
  print_endline "  PASSED"

let test_form_handlers_ignored () =
  print_endline "Test: form event handlers ignored on SSR";
  let submit_handler : Html.event -> unit = fun _ -> () in
  let input_handler : Html.event -> unit = fun _ -> () in
  let html = Html.to_string (
    Html.(form ~onsubmit:submit_handler ~children:[
      input ~oninput:input_handler ~onchange:input_handler ();
      button ~children:[text "Go"] ()
    ] ())
  ) in
  assert (contains html "<form>");
  assert (contains html "<input");
  (* Should not contain any event handler attributes *)
  assert (not (contains html "onclick"));
  assert (not (contains html "onsubmit"));
  assert (not (contains html "oninput"));
  print_endline "  PASSED"

(* ============ Complex Examples ============ *)

let test_counter_component () =
  print_endline "Test: Counter component renders";
  let count, _set_count = Signal.create 0 in
  let html = Render.to_string (fun () ->
    Html.(div ~class_:"counter" ~children:[
      p ~children:[text "Count: "; reactive_text count] ();
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

(* ============ Data Attribute Tests ============ *)

let test_data_attributes () =
  print_endline "Test: data-* attributes render correctly";
  let node = Html.(div ~data:[("testid", "my-div"); ("value", "42")] ~children:[text "Content"] ()) in
  let html = Html.to_string node in
  assert (contains html "data-testid=\"my-div\"");
  assert (contains html "data-value=\"42\"");
  print_endline "  PASSED"

let test_data_attributes_xss_protection () =
  print_endline "Test: data-* attribute keys with XSS attempts are rejected";
  (* Keys with special characters should be filtered out *)
  let node = Html.(div ~data:[
    ("valid-key", "ok");
    ("\" onclick=\"", "xss-attempt");  (* Should be rejected *)
    ("normal", "value")
  ] ~children:[] ()) in
  let html = Html.to_string node in
  assert (contains html "data-valid-key=\"ok\"");
  assert (contains html "data-normal=\"value\"");
  (* The XSS attempt should NOT appear *)
  assert (not (contains html "onclick"));
  assert (not (contains html "xss-attempt"));
  print_endline "  PASSED"

let test_data_attributes_key_validation () =
  print_endline "Test: data-* attribute key validation";
  let node = Html.(div ~data:[
    ("valid123", "ok");           (* alphanumeric - valid *)
    ("with-hyphen", "ok");        (* hyphen - valid *)
    ("with_underscore", "ok");    (* underscore - valid *)
    ("with.period", "ok");        (* period - valid *)
    ("xmlstart", "rejected");     (* starts with xml - invalid *)
    ("XMLStart", "rejected");     (* starts with XML - invalid *)
    ("", "rejected");             (* empty - invalid *)
    ("has space", "rejected");    (* space - invalid *)
    ("has<bracket", "rejected");  (* special char - invalid *)
  ] ~children:[] ()) in
  let html = Html.to_string node in
  assert (contains html "data-valid123=\"ok\"");
  assert (contains html "data-with-hyphen=\"ok\"");
  assert (contains html "data-with_underscore=\"ok\"");
  assert (contains html "data-with.period=\"ok\"");
  (* Invalid keys should not appear *)
  assert (not (contains html "xmlstart"));
  assert (not (contains html "XMLStart"));
  assert (not (contains html "has space"));
  assert (not (contains html "has<bracket"));
  print_endline "  PASSED"

(* ============ ARIA Attribute Tests ============ *)

let test_aria_label () =
  print_endline "Test: aria-label attribute";
  let node = Html.(button ~aria_label:"Close dialog" ~children:[text "X"] ()) in
  let html = Html.to_string node in
  assert (contains html "aria-label=\"Close dialog\"");
  print_endline "  PASSED"

let test_aria_hidden () =
  print_endline "Test: aria-hidden attribute";
  let node = Html.(div ~aria_hidden:true ~children:[text "Hidden from screen readers"] ()) in
  let html = Html.to_string node in
  assert (contains html "aria-hidden=\"true\"");
  let node2 = Html.(span ~aria_hidden:false ~children:[text "Visible"] ()) in
  let html2 = Html.to_string node2 in
  assert (contains html2 "aria-hidden=\"false\"");
  print_endline "  PASSED"

let test_aria_expanded () =
  print_endline "Test: aria-expanded attribute";
  let node = Html.(button ~aria_expanded:true ~aria_controls:"menu-1" ~children:[text "Menu"] ()) in
  let html = Html.to_string node in
  assert (contains html "aria-expanded=\"true\"");
  assert (contains html "aria-controls=\"menu-1\"");
  print_endline "  PASSED"

let test_role_attribute () =
  print_endline "Test: role attribute";
  let node = Html.(div ~role:"navigation" ~children:[text "Nav"] ()) in
  let html = Html.to_string node in
  assert (contains html "role=\"navigation\"");
  let node2 = Html.(section ~aria_labelledby:"heading-1" ~children:[text "Content"] ()) in
  let html2 = Html.to_string node2 in
  assert (contains html2 "aria-labelledby=\"heading-1\"");
  print_endline "  PASSED"

(* ============ Custom Attributes Tests ============ *)

let test_custom_attrs_single () =
  print_endline "Test: Single custom attribute with ~attrs";
  let node = Html.(div ~attrs:[("data-test", "value")] ~children:[text "Test"] ()) in
  let html = Html.to_string node in
  assert (contains html "data-test=\"value\"");
  assert (contains html ">Test</div>");
  print_endline "  PASSED"

let test_custom_attrs_multiple () =
  print_endline "Test: Multiple custom attributes with ~attrs";
  let node = Html.(div ~attrs:[("data-id", "123"); ("data-category", "items"); ("aria-custom", "value")] ~children:[text "Multi"] ()) in
  let html = Html.to_string node in
  assert (contains html "data-id=\"123\"");
  assert (contains html "data-category=\"items\"");
  assert (contains html "aria-custom=\"value\"");
  assert (contains html ">Multi</div>");
  print_endline "  PASSED"

let test_custom_attrs_xss_protection_ssr () =
  print_endline "Test: XSS protection - attribute values are escaped on SSR";
  let node = Html.(div ~attrs:[("data-evil", "<script>alert(1)</script>")] ~children:[text "Content"] ()) in
  let html = Html.to_string node in
  assert (not (contains html "<script>"));
  assert (contains html "&lt;script&gt;alert(1)&lt;/script&gt;");
  print_endline "  PASSED"

let test_data_vs_attrs_parameter () =
  print_endline "Test: ~data parameter (with validation) vs ~attrs (no validation)";
  (* ~data validates keys, ~attrs does not *)
  let node1 = Html.(div ~data:[("filter", "type1"); ("count", "5")] ~children:[text "Using ~data"] ()) in
  let node2 = Html.(div ~attrs:[("data-filter", "type1"); ("data-count", "5")] ~children:[text "Using ~attrs"] ()) in
  let html1 = Html.to_string node1 in
  let html2 = Html.to_string node2 in
  assert (contains html1 "data-filter=\"type1\"");
  assert (contains html1 "data-count=\"5\"");
  assert (contains html2 "data-filter=\"type1\"");
  assert (contains html2 "data-count=\"5\"");
  print_endline "  PASSED"

let test_custom_attrs_empty () =
  print_endline "Test: Empty ~attrs list";
  let node = Html.(div ~attrs:[] ~children:[text "Empty attrs"] ()) in
  let html = Html.to_string node in
  assert (contains html ">Empty attrs</div>");
  print_endline "  PASSED"

let test_custom_attrs_with_standard_attrs () =
  print_endline "Test: Custom attrs coexist with standard attributes";
  let node = Html.(input ~type_:"text" ~id:"test" ~class_:"input" ~attrs:[("data-validate", "true")] ()) in
  let html = Html.to_string node in
  assert (contains html "type=\"text\"");
  assert (contains html "id=\"test\"");
  assert (contains html "class=\"input\"");
  assert (contains html "data-validate=\"true\"");
  print_endline "  PASSED"

(* ============ New HTML Attribute Tests ============ *)

let test_anchor_rel () =
  print_endline "Test: anchor rel attribute";
  let node = Html.(a ~href:"https://example.com" ~target:"_blank" ~rel:"noopener noreferrer" ~children:[text "External"] ()) in
  let html = Html.to_string node in
  assert (contains html "rel=\"noopener noreferrer\"");
  assert (contains html "target=\"_blank\"");
  print_endline "  PASSED"

let test_anchor_download () =
  print_endline "Test: anchor download attribute";
  let node = Html.(a ~href:"/file.pdf" ~download:"document.pdf" ~children:[text "Download PDF"] ()) in
  let html = Html.to_string node in
  assert (contains html "download=\"document.pdf\"");
  print_endline "  PASSED"

let test_input_accept () =
  print_endline "Test: input accept attribute";
  let node = Html.(input ~type_:"file" ~accept:"image/*,.pdf" ()) in
  let html = Html.to_string node in
  assert (contains html "accept=\"image/*,.pdf\"");
  print_endline "  PASSED"

let test_input_min_max_step () =
  print_endline "Test: input min, max, step attributes";
  let node = Html.(input ~type_:"number" ~min:"0" ~max:"100" ~step:"5" ()) in
  let html = Html.to_string node in
  assert (contains html "min=\"0\"");
  assert (contains html "max=\"100\"");
  assert (contains html "step=\"5\"");
  (* Also test with date inputs *)
  let node2 = Html.(input ~type_:"date" ~min:"2024-01-01" ~max:"2024-12-31" ()) in
  let html2 = Html.to_string node2 in
  assert (contains html2 "min=\"2024-01-01\"");
  assert (contains html2 "max=\"2024-12-31\"");
  print_endline "  PASSED"

let test_input_readonly () =
  print_endline "Test: input readonly attribute";
  let node = Html.(input ~type_:"text" ~value:"Can't change" ~readonly:true ()) in
  let html = Html.to_string node in
  assert (contains html "readonly");
  let node2 = Html.(textarea ~readonly:true ~children:[text "Read only text"] ()) in
  let html2 = Html.to_string node2 in
  assert (contains html2 "readonly");
  print_endline "  PASSED"

let test_tabindex () =
  print_endline "Test: tabindex attribute";
  let node = Html.(div ~tabindex:0 ~children:[text "Focusable div"] ()) in
  let html = Html.to_string node in
  assert (contains html "tabindex=\"0\"");
  let node2 = Html.(h1 ~tabindex:(-1) ~children:[text "Not in tab order"] ()) in
  let html2 = Html.to_string node2 in
  assert (contains html2 "tabindex=\"-1\"");
  print_endline "  PASSED"

let test_img_srcset_sizes () =
  print_endline "Test: img srcset and sizes attributes";
  let node = Html.(img 
    ~src:"/img/small.jpg" 
    ~srcset:"/img/small.jpg 480w, /img/medium.jpg 800w, /img/large.jpg 1200w"
    ~sizes:"(max-width: 600px) 480px, (max-width: 900px) 800px, 1200px"
    ~alt:"Responsive image"
    ()) in
  let html = Html.to_string node in
  assert (contains html "srcset=");
  assert (contains html "sizes=");
  assert (contains html "480w");
  print_endline "  PASSED"

(* ============ SVG Element Tests ============ *)

let test_svg_ellipse () =
  print_endline "Test: SVG ellipse element";
  let node = Html.Svg.(ellipse ~cx:"100" ~cy:"50" ~rx:"80" ~ry:"40" ~fill:"red" ~children:[] ()) in
  let html = Html.to_string node in
  assert (contains html "<ellipse");
  assert (contains html "cx=\"100\"");
  assert (contains html "cy=\"50\"");
  assert (contains html "rx=\"80\"");
  assert (contains html "ry=\"40\"");
  print_endline "  PASSED"

let test_svg_polygon_polyline () =
  print_endline "Test: SVG polygon and polyline elements";
  let polygon = Html.Svg.(polygon ~points:"50,0 100,100 0,100" ~fill:"blue" ~children:[] ()) in
  let html1 = Html.to_string polygon in
  assert (contains html1 "<polygon");
  assert (contains html1 "points=\"50,0 100,100 0,100\"");
  let polyline = Html.Svg.(polyline ~points:"0,0 50,50 100,0" ~stroke:"black" ~fill:"none" ~children:[] ()) in
  let html2 = Html.to_string polyline in
  assert (contains html2 "<polyline");
  assert (contains html2 "fill=\"none\"");
  print_endline "  PASSED"

let test_svg_stroke_linecap_linejoin () =
  print_endline "Test: SVG stroke-linecap and stroke-linejoin attributes";
  let node = Html.Svg.(path 
    ~d:"M 10 10 L 50 50 L 90 10" 
    ~stroke:"black" 
    ~stroke_width:"5"
    ~stroke_linecap:"round"
    ~stroke_linejoin:"round"
    ~fill:"none"
    ~children:[] ()) in
  let html = Html.to_string node in
  assert (contains html "stroke-linecap=\"round\"");
  assert (contains html "stroke-linejoin=\"round\"");
  print_endline "  PASSED"

let test_svg_gradient () =
  print_endline "Test: SVG gradient elements";
  let node = Html.Svg.(linearGradient ~id:"grad1" ~x1:"0%" ~y1:"0%" ~x2:"100%" ~y2:"0%" ~children:[
    stop ~offset:"0%" ~stop_color:"red" ();
    stop ~offset:"100%" ~stop_color:"blue" ()
  ] ()) in
  let html = Html.to_string node in
  assert (contains html "<linearGradient");
  assert (contains html "id=\"grad1\"");
  assert (contains html "<stop");
  assert (contains html "stop-color=\"red\"");
  let radial = Html.Svg.(radialGradient ~id:"grad2" ~cx:"50%" ~cy:"50%" ~r:"50%" ~children:[
    stop ~offset:"0%" ~stop_color:"white" ()
  ] ()) in
  let html2 = Html.to_string radial in
  assert (contains html2 "<radialGradient");
  print_endline "  PASSED"

let test_svg_defs_use () =
  print_endline "Test: SVG defs and use elements";
  let node = Html.Svg.(svg ~viewBox:"0 0 100 100" ~children:[
    defs ~children:[
      symbol ~id:"icon" ~viewBox:"0 0 24 24" ~children:[
        circle ~cx:"12" ~cy:"12" ~r:"10" ~fill:"blue" ~children:[] ()
      ] ()
    ] ();
    use ~href:"#icon" ~x:"10" ~y:"10" ()
  ] ()) in
  let html = Html.to_string node in
  assert (contains html "<defs>");
  assert (contains html "<symbol");
  assert (contains html "id=\"icon\"");
  assert (contains html "<use");
  assert (contains html "href=\"#icon\"");
  print_endline "  PASSED"

let test_svg_text_tspan () =
  print_endline "Test: SVG text and tspan elements";
  let node = Html.Svg.(text_ ~x:"10" ~y:"20" ~font_size:"16" ~font_family:"Arial" ~fill:"black" ~children:[
    Html.text "Hello ";
    tspan ~fill:"red" ~children:[Html.text "World"] ()
  ] ()) in
  let html = Html.to_string node in
  assert (contains html "<text");
  assert (contains html "font-size=\"16\"");
  assert (contains html "font-family=\"Arial\"");
  assert (contains html "<tspan");
  assert (contains html "fill=\"red\"");
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
  test_custom_attrs_single ();
  test_custom_attrs_multiple ();
  test_custom_attrs_xss_protection_ssr ();
  test_data_vs_attrs_parameter ();
  test_custom_attrs_empty ();
  test_custom_attrs_with_standard_attrs ();
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

  print_endline "\n-- Reactive Text Tests --";
  test_reactive_text ();
  test_reactive_text_of ();
  test_reactive_text_string ();
  test_reactive_text_marker_sequence ();

  print_endline "\n-- Event Handler Tests --";
  test_onclick_ignored ();
  test_button_onclick_ignored ();
  test_form_handlers_ignored ();

  print_endline "\n-- Complex Examples --";
  test_counter_component ();
  test_full_page ();

  print_endline "\n-- Data Attribute Tests --";
  test_data_attributes ();
  test_data_attributes_xss_protection ();
  test_data_attributes_key_validation ();

  print_endline "\n-- ARIA Attribute Tests --";
  test_aria_label ();
  test_aria_hidden ();
  test_aria_expanded ();
  test_role_attribute ();

  print_endline "\n-- New HTML Attribute Tests --";
  test_anchor_rel ();
  test_anchor_download ();
  test_input_accept ();
  test_input_min_max_step ();
  test_input_readonly ();
  test_tabindex ();
  test_img_srcset_sizes ();

  print_endline "\n-- SVG Element Tests --";
  test_svg_ellipse ();
  test_svg_polygon_polyline ();
  test_svg_stroke_linecap_linejoin ();
  test_svg_gradient ();
  test_svg_defs_use ();
  test_svg_text_tspan ();

  print_endline "\n=== All tests passed! ===\n"

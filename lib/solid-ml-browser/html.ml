(** DOM element creation functions.
    
    These functions mirror the solid-ml-html API but create actual DOM nodes
    instead of HTML strings. This allows the same component code to work on
    both server (generating HTML) and client (creating DOM).
 *)

[@@@warning "-32"] (* Allow unused portal function *)

open Dom

type 'a signal = 'a Reactive_core.signal
type event = Dom.event

let svg_namespace = "http://www.w3.org/2000/svg"

(** {1 Node Types} *)

(** A node that can be rendered to the DOM *)
type node =
  | Element of element
  | Text of text_node
  | Fragment of document_fragment
  | Empty

(** {1 Node Conversion} *)

(** Convert our node type to a DOM node for appending *)
let to_dom_node = function
  | Element el -> node_of_element el
  | Text txt -> node_of_text txt
  | Fragment frag -> node_of_fragment frag
  | Empty -> node_of_text (create_text_node document "")

(** Append a node to an element *)
let append_to_element parent child =
  append_child parent (to_dom_node child)

(** Append a node to a fragment *)
let append_to_fragment frag child =
  fragment_append_child frag (to_dom_node child)

(** {1 Attribute Helpers} *)

let set_opt_attr el name = function
  | Some v -> set_attribute el name v
  | None -> ()

let set_bool_attr el name value =
  if value then set_attribute el name ""
  else remove_attribute el name

(** Validate data-* attribute key.
    Per HTML5 spec, data attribute names must:
    - Contain only ASCII letters, digits, hyphens, underscores, and periods
    - Not start with "xml" (case-insensitive)
    Invalid keys are silently filtered out for security. *)
let is_valid_data_key s =
  let len = String.length s in
  if len = 0 then false
  else if len >= 3 && 
    (s.[0] = 'x' || s.[0] = 'X') && 
    (s.[1] = 'm' || s.[1] = 'M') && 
    (s.[2] = 'l' || s.[2] = 'L') then false
  else
    let rec check i =
      if i >= len then true
      else match s.[i] with
        | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' -> check (i + 1)
        | _ -> false
    in
    check 0

(** Helper to add data-* attributes with validation *)
let set_data_attrs el data =
  List.iter (fun (k, v) -> 
    if is_valid_data_key k then set_attribute el ("data-" ^ k) v
    (* Invalid keys are silently skipped for security *)
  ) data

(** Helper to set int attribute *)
let set_int_attr el name = function
  | Some n -> set_attribute el name (string_of_int n)
  | None -> ()

(** Escape/sanitize attribute names for browser DOM.
    Only allows safe characters: a-z, A-Z, 0-9, hyphen, underscore, period, colon (for namespaced attrs).
    Other characters are replaced with underscore. *)
let escape_attr_name s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' | ':' -> Buffer.add_char buf c
    | _ -> ()  (* Drop unsafe characters *)
  ) s;
  Buffer.contents buf

(** Helper to set custom attributes *)
let set_attrs el attrs =
  List.iter (fun (k, v) -> 
    set_attribute el (escape_attr_name k) v  (* Escape attribute names *)
  ) attrs

(** {1 Text Content} *)

let text s = Text (create_text_node document s)
let int n = text (string_of_int n)
let float f = text (string_of_float f)
let empty = Empty

(** Helper for hydration *)
let get_or_create_text_node key initial_value =
  match Hydration.adopt_text_node key with
  | Some txt -> txt
  | None -> create_text_node document initial_value

let reactive_text signal =
  let key = Hydration.next_hydration_key () in
  let initial = string_of_int (Reactive_core.get_signal signal) in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (string_of_int (Reactive_core.get_signal signal))
  );
  Text txt

let reactive_text_of fmt signal =
  let key = Hydration.next_hydration_key () in
  let initial = fmt (Reactive_core.get_signal signal) in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (fmt (Reactive_core.get_signal signal))
  );
  Text txt

let reactive_text_string signal =
  let key = Hydration.next_hydration_key () in
  let initial = Reactive_core.get_signal signal in
  let txt = get_or_create_text_node key initial in
  Reactive_core.create_effect (fun () ->
    text_set_data txt (Reactive_core.get_signal signal)
  );
  Text txt
  
let signal_text = reactive_text

(** {1 Fragment} *)

(** Create a fragment from a list of nodes.
    Unlike wrapping in a span, this preserves the flat structure. *)
let fragment children =
  let frag = create_document_fragment document in
  List.iter (append_to_fragment frag) children;
  Fragment frag

(** {1 Element Creation} *)

(** Low-level element creation with event handler support and hydration adoption *)
let make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children =
  (* Try to adopt existing element during hydration *)
  let el, adopted = match Hydration.adopt_element tag with
    | Some existing -> (existing, true)
    | None -> (create_element document tag, false)
  in
  (* Set attributes (even on adopted elements to ensure consistency) *)
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "style" style;
  (* Attach event handlers *)
  (match onclick with Some h -> add_event_listener el "click" h | None -> ());
  (match oninput with Some h -> add_event_listener el "input" h | None -> ());
  (match onchange with Some h -> add_event_listener el "change" h | None -> ());
  (match onkeydown with Some h -> add_event_listener el "keydown" h | None -> ());
  (match onsubmit with Some h -> add_event_listener el "submit" h | None -> ());
  (* Process children with hydration cursor *)
  Hydration.enter_children el;
  if not adopted then
    (* Only append children to non-adopted elements *)
    List.iter (append_to_element el) children
  else
    (* For adopted elements, still process children to set up reactive bindings *)
    List.iter (fun child ->
      match child with
      | Text _ | Empty -> () (* Text nodes already adopted via hydration markers *)
      | Element _ | Fragment _ ->
        (* Child elements will adopt themselves via recursive make_element calls *)
        ()
    ) children;
  Hydration.exit_children ();
  Element el

(** Helper to create element and set extra attributes *)
let make_element_with_attrs tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit ?(attrs=[]) extra_attrs children =
  let el_node = make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children in
  match el_node with
  | Element el ->
      extra_attrs el;
      set_attrs el attrs;
      Element el
  | _ -> el_node

(** {1 Document Structure} *)

let div ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "div" ?id ?class_ ?style ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    (match aria_hidden with Some b -> set_attribute el "aria-hidden" (string_of_bool b) | None -> ());
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let span ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "span" ?id ?class_ ?style ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    (match aria_hidden with Some b -> set_attribute el "aria-hidden" (string_of_bool b) | None -> ());
    set_data_attrs el data
  ) children

let p ?id ?class_ ?role ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "p" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let pre ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "pre" ?id ?class_ ~attrs (fun _ -> ()) children

let code ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "code" ?id ?class_ ~attrs (fun _ -> ()) children

(** {1 Headings} *)

let h1 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h1" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h2 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h2" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h3 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h3" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h4 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h4" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h5 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h5" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children
let h6 ?id ?class_ ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "h6" ?id ?class_ ?onclick ~attrs (fun el ->
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

(** {1 Sectioning} *)

let header ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "header" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let footer ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "footer" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let main ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "main" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let nav ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "nav" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_data_attrs el data
  ) children
let section ?id ?class_ ?role ?aria_label ?aria_labelledby ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "section" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_opt_attr el "aria-labelledby" aria_labelledby;
    set_data_attrs el data
  ) children
let article ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "article" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children
let aside ?id ?class_ ?role ?aria_label ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "aside" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_opt_attr el "aria-label" aria_label;
    set_data_attrs el data
  ) children

(** {1 Inline Elements} *)

let a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "a" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "href" href;
    set_opt_attr el "target" target;
    set_opt_attr el "rel" rel;
    set_opt_attr el "download" download;
    set_opt_attr el "hreflang" hreflang;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let strong ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "strong" ?id ?class_ ~attrs (fun _ -> ()) children

let em ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "em" ?id ?class_ ~attrs (fun _ -> ()) children

let br ?(attrs=[]) () =
  make_element_with_attrs "br" ~attrs (fun _ -> ()) []

let hr ?class_ ?(attrs=[]) () =
  make_element_with_attrs "hr" ?class_ ~attrs (fun _ -> ()) []

(** {1 Lists} *)

let ul ?id ?class_ ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "ul" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let ol ?id ?class_ ?start ?role ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "ol" ?id ?class_ ~attrs (fun el ->
    (match start with Some n -> set_attribute el "start" (string_of_int n) | None -> ());
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

let li ?id ?class_ ?role ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "li" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "role" role;
    set_data_attrs el data
  ) children

(** {1 Tables} *)

let table ?id ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "table" ?id ?class_ ~attrs (fun _ -> ()) children

let thead ?(attrs=[]) ~children () =
  make_element_with_attrs "thead" ~attrs (fun _ -> ()) children

let tbody ?(attrs=[]) ~children () =
  make_element_with_attrs "tbody" ~attrs (fun _ -> ()) children

let tfoot ?(attrs=[]) ~children () =
  make_element_with_attrs "tfoot" ~attrs (fun _ -> ()) children

let tr ?class_ ?(attrs=[]) ~children () =
  make_element_with_attrs "tr" ?class_ ~attrs (fun _ -> ()) children

let th ?class_ ?scope ?colspan ?rowspan ?(attrs=[]) ~children () =
  make_element_with_attrs "th" ?class_ ~attrs (fun el ->
    set_opt_attr el "scope" scope;
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

let td ?class_ ?colspan ?rowspan ?(attrs=[]) ~children () =
  make_element_with_attrs "td" ?class_ ~attrs (fun el ->
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

(** {1 Forms} *)

let form ?id ?class_ ?action ?method_ ?enctype ?onsubmit ?(attrs=[]) ~children () =
  make_element_with_attrs "form" ?id ?class_ ?onsubmit ~attrs (fun el ->
    set_opt_attr el "action" action;
    set_opt_attr el "method" method_;
    set_opt_attr el "enctype" enctype
  ) children

let input ?id ?class_ ?type_ ?name ?value ?placeholder ?accept ?min ?max ?step
    ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false) ?(readonly=false)
    ?tabindex ?oninput ?onchange ?onkeydown ?(data=[]) ?(attrs=[]) () =
  make_element_with_attrs "input" ?id ?class_ ?oninput ?onchange ?onkeydown ~attrs (fun el ->
    set_opt_attr el "type" type_;
    set_opt_attr el "name" name;
    set_opt_attr el "value" value;
    set_opt_attr el "placeholder" placeholder;
    set_opt_attr el "accept" accept;
    set_opt_attr el "min" min;
    set_opt_attr el "max" max;
    set_opt_attr el "step" step;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "autofocus" autofocus;
    set_bool_attr el "readonly" readonly;
    set_int_attr el "tabindex" tabindex;
    if checked then element_set_checked el true;
    set_data_attrs el data
  ) []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols 
    ?(required=false) ?(disabled=false) ?(autofocus=false) ?(readonly=false)
    ?tabindex ?oninput ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "textarea" ?id ?class_ ?oninput ~attrs (fun el ->
    set_opt_attr el "name" name;
    set_opt_attr el "placeholder" placeholder;
    (match rows with Some n -> set_attribute el "rows" (string_of_int n) | None -> ());
    (match cols with Some n -> set_attribute el "cols" (string_of_int n) | None -> ());
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "autofocus" autofocus;
    set_bool_attr el "readonly" readonly;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) 
    ?(autofocus=false) ?tabindex ?onchange ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "select" ?id ?class_ ?onchange ~attrs (fun el ->
    set_opt_attr el "name" name;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "multiple" multiple;
    set_bool_attr el "autofocus" autofocus;
    set_int_attr el "tabindex" tabindex;
    set_data_attrs el data
  ) children

let option ?value ?(selected=false) ?(disabled=false) ?(attrs=[]) ~children () =
  make_element_with_attrs "option" ~attrs (fun el ->
    set_opt_attr el "value" value;
    set_bool_attr el "selected" selected;
    set_bool_attr el "disabled" disabled
  ) children

let label ?id ?class_ ?for_ ?(attrs=[]) ~children () =
  make_element_with_attrs "label" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "for" for_
  ) children

let button ?id ?class_ ?type_ ?(disabled=false) ?tabindex ?aria_label ?aria_expanded ?aria_controls ?aria_haspopup ?onclick ?(data=[]) ?(attrs=[]) ~children () =
  make_element_with_attrs "button" ?id ?class_ ?onclick ~attrs (fun el ->
    set_opt_attr el "type" type_;
    set_bool_attr el "disabled" disabled;
    set_int_attr el "tabindex" tabindex;
    set_opt_attr el "aria-label" aria_label;
    (match aria_expanded with Some b -> set_attribute el "aria-expanded" (string_of_bool b) | None -> ());
    set_opt_attr el "aria-controls" aria_controls;
    (match aria_haspopup with Some b -> set_attribute el "aria-haspopup" (string_of_bool b) | None -> ());
    set_data_attrs el data
  ) children

(** {1 Media} *)

let img ?id ?class_ ?src ?alt ?width ?height ?loading ?srcset ?sizes ?(data=[]) ?(attrs=[]) () =
  make_element_with_attrs "img" ?id ?class_ ~attrs (fun el ->
    set_opt_attr el "src" src;
    set_opt_attr el "alt" alt;
    (match width with Some n -> set_attribute el "width" (string_of_int n) | None -> ());
    (match height with Some n -> set_attribute el "height" (string_of_int n) | None -> ());
    set_opt_attr el "loading" loading;
    set_opt_attr el "srcset" srcset;
    set_opt_attr el "sizes" sizes;
    set_data_attrs el data
  ) []

(** {1 Portal} *)

(** {1 Portal} *)

(** Internal reference to document.body for portal mounting *)
let document_body : element option ref = ref None

let get_document_body () =
  match !document_body with
  | Some body -> body
  | None ->
    let body = Option.get (get_element_by_id document "body") in
    document_body := Some body;
    body

(** Create a portal that mounts children into a different DOM node.
    - target: DOM element to mount into (None = document.body)
    - is_svg: Use <g> wrapper instead of <div> for SVG context
    - children: Content to render in the portal *)
let portal ?target ?(is_svg=false) ~(children : node) () : node =
  let _placeholder = create_comment document "portal" in
  
  let mounted_node : Dom.node option ref = ref None in
  
  let cleanup () =
    match !mounted_node with
    | Some node -> remove_node node
    | None -> ()
  in
  
  Reactive_core.create_effect (fun () ->
    let target = match target with
      | Some el -> el
      | None -> get_document_body ()
    in
    
    let children_node = to_dom_node children in
    
    let content = if is_svg then
      children_node
    else if get_tag_name target = "HEAD" then
      children_node
    else
      let wrapper = create_element document "div" in
      set_attribute wrapper "data-solid-ml-portal" "";
      append_child wrapper children_node;
      node_of_element wrapper
    in
    
    append_child target content;
    mounted_node := Some content;
    
    Reactive_core.on_cleanup cleanup
  );
  
  Text (create_text_node document "")

(** {1 SVG Elements} *)

module Svg = struct
  let svg ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "svg" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "viewBox" viewBox;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "fill" fill;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "g" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "transform" transform;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "circle" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "r" r;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "ellipse" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "rx" rx;
    set_opt_attr el "ry" ry;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "rect" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "rx" rx;
    set_opt_attr el "ry" ry;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "line" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x1" x1;
    set_opt_attr el "y1" y1;
    set_opt_attr el "x2" x2;
    set_opt_attr el "y2" y2;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "polyline" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "points" points;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "polygon" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "points" points;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "path" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "d" d;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_opt_attr el "stroke-linecap" stroke_linecap;
    set_opt_attr el "stroke-linejoin" stroke_linejoin;
    set_opt_attr el "fill-rule" fill_rule;
    set_opt_attr el "clip-rule" clip_rule;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "text" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "dx" dx;
    set_opt_attr el "dy" dy;
    set_opt_attr el "text-anchor" text_anchor;
    set_opt_attr el "font-size" font_size;
    set_opt_attr el "font-family" font_family;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let tspan ?id ?class_ ?x ?y ?dx ?dy ?fill ?onclick ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "tspan" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "dx" dx;
    set_opt_attr el "dy" dy;
    set_opt_attr el "fill" fill;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let defs ?id ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "defs" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let use ?id ?class_ ?href ?x ?y ?width ?height ?onclick ?(attrs=[]) () =
    let el = create_element_ns document svg_namespace "use" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "href" href;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_attrs el attrs;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    Element el

  let symbol ?id ?viewBox ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "symbol" in
    set_opt_attr el "id" id;
    set_opt_attr el "viewBox" viewBox;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let clipPath ?id ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "clipPath" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let mask ?id ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "mask" in
    set_opt_attr el "id" id;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let linearGradient ?id ?x1 ?y1 ?x2 ?y2 ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "linearGradient" in
    set_opt_attr el "id" id;
    set_opt_attr el "x1" x1;
    set_opt_attr el "y1" y1;
    set_opt_attr el "x2" x2;
    set_opt_attr el "y2" y2;
    set_opt_attr el "gradientUnits" gradientUnits;
    set_opt_attr el "gradientTransform" gradientTransform;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let radialGradient ?id ?cx ?cy ?r ?fx ?fy ?gradientUnits ?gradientTransform ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "radialGradient" in
    set_opt_attr el "id" id;
    set_opt_attr el "cx" cx;
    set_opt_attr el "cy" cy;
    set_opt_attr el "r" r;
    set_opt_attr el "fx" fx;
    set_opt_attr el "fy" fy;
    set_opt_attr el "gradientUnits" gradientUnits;
    set_opt_attr el "gradientTransform" gradientTransform;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el

  let stop ?offset ?stop_color ?stop_opacity ?(attrs=[]) () =
    let el = create_element_ns document svg_namespace "stop" in
    set_opt_attr el "offset" offset;
    set_opt_attr el "stop-color" stop_color;
    set_opt_attr el "stop-opacity" stop_opacity;
    set_attrs el attrs;
    Element el

  let image ?id ?class_ ?href ?x ?y ?width ?height ?preserveAspectRatio ?(attrs=[]) () =
    let el = create_element_ns document svg_namespace "image" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "href" href;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_opt_attr el "preserveAspectRatio" preserveAspectRatio;
    set_attrs el attrs;
    Element el

  let foreignObject ?id ?class_ ?x ?y ?width ?height ?(attrs=[]) ~children () =
    let el = create_element_ns document svg_namespace "foreignObject" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    set_attrs el attrs;
    List.iter (append_to_element el) children;
    Element el
end

let svg ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?attrs ~children () =
  Svg.svg ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ?attrs ~children ()

let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?attrs ~children () =
  Svg.g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ?attrs ~children ()

let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children () =
  Svg.polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ?attrs ~children ()

let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?attrs ~children () =
  Svg.path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ?attrs ~children ()

let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?attrs ~children () =
  Svg.text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ?attrs ~children ()

(** {1 Node Access} *)

(** Get the underlying DOM element (for direct manipulation) *)
let get_element = function
  | Element el -> Some el
  | Text _ | Fragment _ | Empty -> None

(** Get the underlying DOM text node *)
let get_text_node = function
  | Text txt -> Some txt
  | Element _ | Fragment _ | Empty -> None

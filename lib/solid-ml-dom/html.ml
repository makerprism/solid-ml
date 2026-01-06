(** DOM element creation functions.
    
    These functions mirror the solid-ml-html API but create actual DOM nodes
    instead of HTML strings. This allows the same component code to work on
    both server (generating HTML) and client (creating DOM).
*)

open Dom

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

(** {1 Text Content} *)

let text s = Text (create_text_node document s)
let int n = text (string_of_int n)
let float f = text (string_of_float f)
let empty = Empty

(** {1 Fragment} *)

(** Create a fragment from a list of nodes.
    Unlike wrapping in a span, this preserves the flat structure. *)
let fragment children =
  let frag = create_document_fragment document in
  List.iter (append_to_fragment frag) children;
  Fragment frag

(** {1 Element Creation} *)

(** Low-level element creation with event handler support *)
let make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children =
  let el = create_element document tag in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "style" style;
  (* Attach event handlers *)
  (match onclick with Some h -> add_event_listener el "click" h | None -> ());
  (match oninput with Some h -> add_event_listener el "input" h | None -> ());
  (match onchange with Some h -> add_event_listener el "change" h | None -> ());
  (match onkeydown with Some h -> add_event_listener el "keydown" h | None -> ());
  (match onsubmit with Some h -> add_event_listener el "submit" h | None -> ());
  List.iter (append_to_element el) children;
  Element el

(** {1 Document Structure} *)

let div ?id ?class_ ?style ?onclick ~children () =
  make_element "div" ?id ?class_ ?style ?onclick children

let span ?id ?class_ ?style ?onclick ~children () =
  make_element "span" ?id ?class_ ?style ?onclick children

let p ?id ?class_ ?onclick ~children () =
  make_element "p" ?id ?class_ ?onclick children

let pre ?id ?class_ ~children () =
  make_element "pre" ?id ?class_ children

let code ?id ?class_ ~children () =
  make_element "code" ?id ?class_ children

(** {1 Headings} *)

let h1 ?id ?class_ ?onclick ~children () = make_element "h1" ?id ?class_ ?onclick children
let h2 ?id ?class_ ?onclick ~children () = make_element "h2" ?id ?class_ ?onclick children
let h3 ?id ?class_ ?onclick ~children () = make_element "h3" ?id ?class_ ?onclick children
let h4 ?id ?class_ ?onclick ~children () = make_element "h4" ?id ?class_ ?onclick children
let h5 ?id ?class_ ?onclick ~children () = make_element "h5" ?id ?class_ ?onclick children
let h6 ?id ?class_ ?onclick ~children () = make_element "h6" ?id ?class_ ?onclick children

(** {1 Sectioning} *)

let header ?id ?class_ ~children () = make_element "header" ?id ?class_ children
let footer ?id ?class_ ~children () = make_element "footer" ?id ?class_ children
let main ?id ?class_ ~children () = make_element "main" ?id ?class_ children
let nav ?id ?class_ ~children () = make_element "nav" ?id ?class_ children
let section ?id ?class_ ~children () = make_element "section" ?id ?class_ children
let article ?id ?class_ ~children () = make_element "article" ?id ?class_ children
let aside ?id ?class_ ~children () = make_element "aside" ?id ?class_ children

(** {1 Inline Elements} *)

let a ?id ?class_ ?href ?target ?onclick ~children () =
  let el = create_element document "a" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "href" href;
  set_opt_attr el "target" target;
  (match onclick with Some h -> add_event_listener el "click" h | None -> ());
  List.iter (append_to_element el) children;
  Element el

let strong ?id ?class_ ~children () = make_element "strong" ?id ?class_ children
let em ?id ?class_ ~children () = make_element "em" ?id ?class_ children

let br () = Element (create_element document "br")

let hr ?class_ () =
  let el = create_element document "hr" in
  set_opt_attr el "class" class_;
  Element el

(** {1 Lists} *)

let ul ?id ?class_ ~children () = make_element "ul" ?id ?class_ children

let ol ?id ?class_ ?start ~children () =
  let el = create_element document "ol" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  (match start with Some n -> set_attribute el "start" (string_of_int n) | None -> ());
  List.iter (append_to_element el) children;
  Element el

let li ?id ?class_ ?onclick ~children () = make_element "li" ?id ?class_ ?onclick children

(** {1 Tables} *)

let table ?id ?class_ ~children () = make_element "table" ?id ?class_ children
let thead ~children () = make_element "thead" children
let tbody ~children () = make_element "tbody" children
let tfoot ~children () = make_element "tfoot" children
let tr ?class_ ~children () = make_element "tr" ?class_ children

let th ?class_ ?scope ?colspan ?rowspan ~children () =
  let el = create_element document "th" in
  set_opt_attr el "class" class_;
  set_opt_attr el "scope" scope;
  (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
  (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ());
  List.iter (append_to_element el) children;
  Element el

let td ?class_ ?colspan ?rowspan ~children () =
  let el = create_element document "td" in
  set_opt_attr el "class" class_;
  (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
  (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ());
  List.iter (append_to_element el) children;
  Element el

(** {1 Forms} *)

let form ?id ?class_ ?action ?method_ ?onsubmit ~children () =
  let el = create_element document "form" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "action" action;
  set_opt_attr el "method" method_;
  (match onsubmit with 
   | Some h -> add_event_listener el "submit" h 
   | None -> ());
  List.iter (append_to_element el) children;
  Element el

let input ?id ?class_ ?type_ ?name ?value ?placeholder 
    ?(required=false) ?(disabled=false) ?(checked=false) 
    ?oninput ?onchange ?onkeydown () =
  let el = create_element document "input" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "type" type_;
  set_opt_attr el "name" name;
  set_opt_attr el "value" value;
  set_opt_attr el "placeholder" placeholder;
  set_bool_attr el "required" required;
  set_bool_attr el "disabled" disabled;
  if checked then element_set_checked el true;
  (match oninput with Some h -> add_event_listener el "input" h | None -> ());
  (match onchange with Some h -> add_event_listener el "change" h | None -> ());
  (match onkeydown with Some h -> add_event_listener el "keydown" h | None -> ());
  Element el

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols 
    ?(required=false) ?(disabled=false) ?oninput ~children () =
  let el = create_element document "textarea" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "name" name;
  set_opt_attr el "placeholder" placeholder;
  (match rows with Some n -> set_attribute el "rows" (string_of_int n) | None -> ());
  (match cols with Some n -> set_attribute el "cols" (string_of_int n) | None -> ());
  set_bool_attr el "required" required;
  set_bool_attr el "disabled" disabled;
  (match oninput with Some h -> add_event_listener el "input" h | None -> ());
  List.iter (append_to_element el) children;
  Element el

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) 
    ?onchange ~children () =
  let el = create_element document "select" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "name" name;
  set_bool_attr el "required" required;
  set_bool_attr el "disabled" disabled;
  set_bool_attr el "multiple" multiple;
  (match onchange with Some h -> add_event_listener el "change" h | None -> ());
  List.iter (append_to_element el) children;
  Element el

let option ?value ?(selected=false) ?(disabled=false) ~children () =
  let el = create_element document "option" in
  set_opt_attr el "value" value;
  set_bool_attr el "selected" selected;
  set_bool_attr el "disabled" disabled;
  List.iter (append_to_element el) children;
  Element el

let label ?id ?class_ ?for_ ~children () =
  let el = create_element document "label" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "for" for_;
  List.iter (append_to_element el) children;
  Element el

let button ?id ?class_ ?type_ ?(disabled=false) ?onclick ~children () =
  let el = create_element document "button" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "type" type_;
  set_bool_attr el "disabled" disabled;
  (match onclick with Some h -> add_event_listener el "click" h | None -> ());
  List.iter (append_to_element el) children;
  Element el

(** {1 Media} *)

let img ?id ?class_ ?src ?alt ?width ?height () =
  let el = create_element document "img" in
  set_opt_attr el "id" id;
  set_opt_attr el "class" class_;
  set_opt_attr el "src" src;
  set_opt_attr el "alt" alt;
  (match width with Some n -> set_attribute el "width" (string_of_int n) | None -> ());
  (match height with Some n -> set_attribute el "height" (string_of_int n) | None -> ());
  Element el

(** {1 Node Access} *)

(** Get the underlying DOM element (for direct manipulation) *)
let get_element = function
  | Element el -> Some el
  | Text _ | Fragment _ | Empty -> None

(** Get the underlying DOM text node *)
let get_text_node = function
  | Text txt -> Some txt
  | Element _ | Fragment _ | Empty -> None

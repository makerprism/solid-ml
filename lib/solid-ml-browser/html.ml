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
let make_element_with_attrs tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit attrs children =
  let el_node = make_element tag ?id ?class_ ?style ?onclick ?oninput ?onchange ?onkeydown ?onsubmit children in
  match el_node with
  | Element el ->
      attrs el;
      Element el
  | _ -> el_node

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
  make_element_with_attrs "a" ?id ?class_ ?onclick (fun el ->
    set_opt_attr el "href" href;
    set_opt_attr el "target" target
  ) children

let strong ?id ?class_ ~children () = make_element "strong" ?id ?class_ children
let em ?id ?class_ ~children () = make_element "em" ?id ?class_ children

let br () = make_element "br" []

let hr ?class_ () = make_element "hr" ?class_ []

(** {1 Lists} *)

let ul ?id ?class_ ~children () = make_element "ul" ?id ?class_ children

let ol ?id ?class_ ?start ~children () =
  make_element_with_attrs "ol" ?id ?class_ (fun el ->
    (match start with Some n -> set_attribute el "start" (string_of_int n) | None -> ())
  ) children

let li ?id ?class_ ?onclick ~children () = make_element "li" ?id ?class_ ?onclick children

(** {1 Tables} *)

let table ?id ?class_ ~children () = make_element "table" ?id ?class_ children
let thead ~children () = make_element "thead" children
let tbody ~children () = make_element "tbody" children
let tfoot ~children () = make_element "tfoot" children
let tr ?class_ ~children () = make_element "tr" ?class_ children

let th ?class_ ?scope ?colspan ?rowspan ~children () =
  make_element_with_attrs "th" ?class_ (fun el ->
    set_opt_attr el "scope" scope;
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

let td ?class_ ?colspan ?rowspan ~children () =
  make_element_with_attrs "td" ?class_ (fun el ->
    (match colspan with Some n -> set_attribute el "colspan" (string_of_int n) | None -> ());
    (match rowspan with Some n -> set_attribute el "rowspan" (string_of_int n) | None -> ())
  ) children

(** {1 Forms} *)

let form ?id ?class_ ?action ?method_ ?enctype ?onsubmit ~children () =
  make_element_with_attrs "form" ?id ?class_ ?onsubmit (fun el ->
    set_opt_attr el "action" action;
    set_opt_attr el "method" method_;
    set_opt_attr el "enctype" enctype
  ) children

let input ?id ?class_ ?type_ ?name ?value ?placeholder 
    ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false)
    ?oninput ?onchange ?onkeydown () =
  make_element_with_attrs "input" ?id ?class_ ?oninput ?onchange ?onkeydown (fun el ->
    set_opt_attr el "type" type_;
    set_opt_attr el "name" name;
    set_opt_attr el "value" value;
    set_opt_attr el "placeholder" placeholder;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "autofocus" autofocus;
    if checked then element_set_checked el true
  ) []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols 
    ?(required=false) ?(disabled=false) ?oninput ~children () =
  make_element_with_attrs "textarea" ?id ?class_ ?oninput (fun el ->
    set_opt_attr el "name" name;
    set_opt_attr el "placeholder" placeholder;
    (match rows with Some n -> set_attribute el "rows" (string_of_int n) | None -> ());
    (match cols with Some n -> set_attribute el "cols" (string_of_int n) | None -> ());
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled
  ) children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) 
    ?onchange ~children () =
  make_element_with_attrs "select" ?id ?class_ ?onchange (fun el ->
    set_opt_attr el "name" name;
    set_bool_attr el "required" required;
    set_bool_attr el "disabled" disabled;
    set_bool_attr el "multiple" multiple
  ) children

let option ?value ?(selected=false) ?(disabled=false) ~children () =
  make_element_with_attrs "option" (fun el ->
    set_opt_attr el "value" value;
    set_bool_attr el "selected" selected;
    set_bool_attr el "disabled" disabled
  ) children

let label ?id ?class_ ?for_ ~children () =
  make_element_with_attrs "label" ?id ?class_ (fun el ->
    set_opt_attr el "for" for_
  ) children

let button ?id ?class_ ?type_ ?(disabled=false) ?onclick ~children () =
  make_element_with_attrs "button" ?id ?class_ ?onclick (fun el ->
    set_opt_attr el "type" type_;
    set_bool_attr el "disabled" disabled
  ) children

(** {1 Media} *)

let img ?id ?class_ ?src ?alt ?width ?height ?loading () =
  make_element_with_attrs "img" ?id ?class_ (fun el ->
    set_opt_attr el "src" src;
    set_opt_attr el "alt" alt;
    (match width with Some n -> set_attribute el "width" (string_of_int n) | None -> ());
    (match height with Some n -> set_attribute el "height" (string_of_int n) | None -> ());
    set_opt_attr el "loading" loading
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
  let svg ?id ?class_ ?style ?viewBox ?width ?height ?onclick ~children () =
    let el = create_element_ns document svg_namespace "svg" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "viewBox" viewBox;
    set_opt_attr el "width" width;
    set_opt_attr el "height" height;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let g ?id ?class_ ?style ?transform ?onclick ~children () =
    let el = create_element_ns document svg_namespace "g" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "transform" transform;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?onclick ~children () =
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
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?onclick ~children () =
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
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?onclick ~children () =
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
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?onclick ~children () =
    let el = create_element_ns document svg_namespace "path" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "d" d;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el

  let text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ?onclick ~children () =
    let el = create_element_ns document svg_namespace "text" in
    set_opt_attr el "id" id;
    set_opt_attr el "class" class_;
    set_opt_attr el "style" style;
    set_opt_attr el "x" x;
    set_opt_attr el "y" y;
    set_opt_attr el "fill" fill;
    set_opt_attr el "stroke" stroke;
    set_opt_attr el "stroke-width" stroke_width;
    (match onclick with Some h -> add_event_listener el "click" h | None -> ());
    List.iter (append_to_element el) children;
    Element el
end

let svg ?id ?class_ ?style ?viewBox ?width ?height ?onclick ~children () =
  Svg.svg ?id ?class_ ?style ?viewBox ?width ?height ?onclick ~children ()

let g ?id ?class_ ?style ?transform ?onclick ~children () =
  Svg.g ?id ?class_ ?style ?transform ?onclick ~children ()

let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?onclick ~children () =
  Svg.circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?onclick ~children ()

let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?onclick ~children () =
  Svg.rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?onclick ~children ()

let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?onclick ~children () =
  Svg.line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?onclick ~children ()

let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?onclick ~children () =
  Svg.path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?onclick ~children ()

let text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ?onclick ~children () =
  Svg.text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ?onclick ~children ()

(** {1 Node Access} *)

(** Get the underlying DOM element (for direct manipulation) *)
let get_element = function
  | Element el -> Some el
  | Text _ | Fragment _ | Empty -> None

(** Get the underlying DOM text node *)
let get_text_node = function
  | Text txt -> Some txt
  | Element _ | Fragment _ | Empty -> None

(** HTML element functions for server-side rendering. *)

(** Event type stub for unified interface.
    On SSR, events are never instantiated - handlers are ignored. *)
type event = unit

(** Hydration key counter for marking reactive elements *)
let hydration_key = ref 0

let svg_namespace = "http://www.w3.org/2000/svg"

let next_hydration_key () =
  let key = !hydration_key in
  incr hydration_key;
  key

let reset_hydration_keys () =
  hydration_key := 0

(** HTML node type *)
type node =
  | Text of string
  | Raw of string
  | Element of {
      tag : string;
      attrs : (string * string) list;
      children : node list;
      self_closing : bool;
    }
  | Fragment of node list
  | ReactiveText of { key : int; value : string }

(** Escape HTML special characters in attribute values and text *)
let escape_html s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | '&' -> Buffer.add_string buf "&amp;"
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '"' -> Buffer.add_string buf "&quot;"
    | '\'' -> Buffer.add_string buf "&#x27;"
    | _ -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

(** Escape/sanitize attribute names.
    Only allows safe characters: a-z, A-Z, 0-9, hyphen, underscore, period, colon (for namespaced attrs).
    Other characters are replaced with underscore. *)
let escape_attr_name s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '-' | '_' | '.' | ':' -> Buffer.add_char buf c
    | _ -> Buffer.add_char buf '_'
  ) s;
  Buffer.contents buf

(** Convert node to HTML string *)
let rec to_string node =
  match node with
  | Text s -> escape_html s
  | Raw s -> s
  | ReactiveText { key; value } ->
    Printf.sprintf "<!--hk:%d-->%s<!--/hk-->" key (escape_html value)
  | Fragment children ->
    String.concat "" (List.map to_string children)
  | Element { tag; attrs; children; self_closing } ->
    let attrs_str =
      if attrs = [] then ""
      else
        " " ^ String.concat " " (List.map (fun (k, v) ->
          let safe_key = escape_attr_name k in
          if v = "" then safe_key  (* Boolean attribute *)
          else Printf.sprintf "%s=\"%s\"" safe_key (escape_html v)
        ) attrs)
    in
    if self_closing then
      Printf.sprintf "<%s%s />" tag attrs_str
    else
      let children_str = String.concat "" (List.map to_string children) in
      Printf.sprintf "<%s%s>%s</%s>" tag attrs_str children_str tag

(** Text content constructors *)
let text s = Text s
let int n = Text (string_of_int n)
let float f = Text (string_of_float f)
let raw s = Raw s

(** Reactive text functions - unified API for SSR/browser *)

let reactive_text signal =
  let key = next_hydration_key () in
  let value = string_of_int (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

let reactive_text_of fmt signal =
  let key = next_hydration_key () in
  let value = fmt (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

let reactive_text_string signal =
  let key = next_hydration_key () in
  let value = Solid_ml.Signal.peek signal in
  ReactiveText { key; value }

(** Deprecated aliases for backwards compatibility *)
let signal_text = reactive_text
let signal_text_of = reactive_text_of

(** Common attributes type *)
type common_attrs = {
  id : string option;
  class_ : string option;
  style : string option;
  title : string option;
  data : (string * string) list;
}

let no_attrs = { id = None; class_ = None; style = None; title = None; data = [] }

(** Helper to add optional attribute to list *)
let add_opt name value attrs =
  match value with Some v -> (name, v) :: attrs | None -> attrs

let add_bool name value attrs =
  if value then (name, "") :: attrs else attrs

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
let add_data data attrs =
  List.fold_left (fun acc (k, v) -> 
    if is_valid_data_key k then ("data-" ^ k, v) :: acc 
    else acc  (* Silently skip invalid keys for security *)
  ) attrs data

(** Helper to add int attribute *)
let add_int name value attrs =
  match value with Some n -> (name, string_of_int n) :: attrs | None -> attrs

let element tag ?(self_closing=false) attrs children =
  Element { tag; attrs; children; self_closing }

(** Document structure elements *)
let html ?lang ~children () =
  element "html" (add_opt "lang" lang []) children

let head ~children () = element "head" [] children

let body ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "body" attrs children

let title ~children () = element "title" [] children

let meta ?charset ?name ?property ?content () =
  let attrs = [] |> add_opt "charset" charset |> add_opt "name" name |> add_opt "property" property |> add_opt "content" content in
  element "meta" ~self_closing:true attrs []

let link ?rel ?href ?hreflang ?type_ () =
  let attrs = [] |> add_opt "rel" rel |> add_opt "href" href |> add_opt "hreflang" hreflang |> add_opt "type" type_ in
  element "link" ~self_closing:true attrs []

let script ?src ?type_ ?(defer=false) ?(async=false) ~children () =
  let attrs = [] 
    |> add_opt "src" src 
    |> add_opt "type" type_
    |> add_bool "defer" defer
    |> add_bool "async" async
  in
  element "script" attrs children

(** Content sectioning *)
let header ?id ?class_ ?role ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "header" attrs children

let footer ?id ?class_ ?role ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "footer" attrs children

let main ?id ?class_ ?role ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "main" attrs children

let nav ?id ?class_ ?role ?aria_label ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_data data
  in
  element "nav" attrs children

let section ?id ?class_ ?role ?aria_label ?aria_labelledby ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-labelledby" aria_labelledby
    |> add_data data
  in
  element "section" attrs children

let article ?id ?class_ ?role ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "article" attrs children

let aside ?id ?class_ ?role ?aria_label ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_data data
  in
  element "aside" attrs children

(** Text content *)
let div ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "style" style
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-hidden" (Option.map string_of_bool aria_hidden)
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "div" attrs children

let p ?id ?class_ ?role ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "p" attrs children

let span ?id ?class_ ?style ?role ?aria_label ?aria_hidden ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "style" style
    |> add_opt "role" role
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-hidden" (Option.map string_of_bool aria_hidden)
    |> add_data data
  in
  element "span" attrs children

let pre ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "pre" attrs children

let code ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "code" attrs children

let blockquote ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "blockquote" attrs children

(** Headings *)
let h1 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h1" attrs children

let h2 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h2" attrs children

let h3 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h3" attrs children

let h4 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h4" attrs children

let h5 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h5" attrs children

let h6 ?id ?class_ ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "h6" attrs children

(** Inline text *)
let a ?id ?class_ ?href ?target ?rel ?download ?hreflang ?tabindex ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "href" href
    |> add_opt "target" target
    |> add_opt "rel" rel
    |> add_opt "download" download
    |> add_opt "hreflang" hreflang
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "a" attrs children

let strong ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "strong" attrs children

let em ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "em" attrs children

let br () = element "br" ~self_closing:true [] []

let hr ?class_ () =
  let attrs = [] |> add_opt "class" class_ in
  element "hr" ~self_closing:true attrs []

(** Lists *)
let ul ?id ?class_ ?role ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "ul" attrs children

let ol ?id ?class_ ?start ?role ?(data=[]) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "start" (Option.map string_of_int start)
    |> add_opt "role" role
    |> add_data data
  in
  element "ol" attrs children

let li ?id ?class_ ?role ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "role" role
    |> add_data data
  in
  element "li" attrs children

(** Tables *)
let table ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "table" attrs children

let thead ~children () = element "thead" [] children
let tbody ~children () = element "tbody" [] children
let tfoot ~children () = element "tfoot" [] children

let tr ?class_ ~children () =
  let attrs = [] |> add_opt "class" class_ in
  element "tr" attrs children

let th ?class_ ?scope ?colspan ?rowspan ~children () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_opt "scope" scope
    |> add_opt "colspan" (Option.map string_of_int colspan)
    |> add_opt "rowspan" (Option.map string_of_int rowspan)
  in
  element "th" attrs children

let td ?class_ ?colspan ?rowspan ~children () =
  let attrs = [] 
    |> add_opt "class" class_
    |> add_opt "colspan" (Option.map string_of_int colspan)
    |> add_opt "rowspan" (Option.map string_of_int rowspan)
  in
  element "td" attrs children

(** Forms *)
let form ?id ?class_ ?action ?method_ ?enctype ?onsubmit:_ ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "action" action
    |> add_opt "method" method_
    |> add_opt "enctype" enctype
  in
  element "form" attrs children

let input ?id ?class_ ?type_ ?name ?value ?placeholder ?accept ?min ?max ?step ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false) ?(readonly=false) ?tabindex ?oninput:_ ?onchange:_ ?onkeydown:_ ?(data=[]) () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_opt "name" name
    |> add_opt "value" value
    |> add_opt "placeholder" placeholder
    |> add_opt "accept" accept
    |> add_opt "min" min
    |> add_opt "max" max
    |> add_opt "step" step
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "checked" checked
    |> add_bool "autofocus" autofocus
    |> add_bool "readonly" readonly
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "input" ~self_closing:true attrs []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols ?(required=false) ?(disabled=false) ?(autofocus=false) ?(readonly=false) ?tabindex ?oninput:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_opt "placeholder" placeholder
    |> add_opt "rows" (Option.map string_of_int rows)
    |> add_opt "cols" (Option.map string_of_int cols)
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "autofocus" autofocus
    |> add_bool "readonly" readonly
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "textarea" attrs children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) ?(autofocus=false) ?tabindex ?onchange:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "multiple" multiple
    |> add_bool "autofocus" autofocus
    |> add_int "tabindex" tabindex
    |> add_data data
  in
  element "select" attrs children

let option ?value ?(selected=false) ?(disabled=false) ~children () =
  let attrs = [] 
    |> add_opt "value" value
    |> add_bool "selected" selected
    |> add_bool "disabled" disabled
  in
  element "option" attrs children

let label ?id ?class_ ?for_ ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "for" for_
  in
  element "label" attrs children

let button ?id ?class_ ?type_ ?(disabled=false) ?tabindex ?aria_label ?aria_expanded ?aria_controls ?aria_haspopup ?onclick:_ ?(data=[]) ~children () =
  let attrs = []
    |> add_opt "id" id
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_bool "disabled" disabled
    |> add_int "tabindex" tabindex
    |> add_opt "aria-label" aria_label
    |> add_opt "aria-expanded" (Option.map string_of_bool aria_expanded)
    |> add_opt "aria-controls" aria_controls
    |> add_opt "aria-haspopup" (Option.map string_of_bool aria_haspopup)
    |> add_data data
  in
  element "button" attrs children

let fieldset ?id ?class_ ?(disabled=false) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_bool "disabled" disabled
  in
  element "fieldset" attrs children

let legend ~children () = element "legend" [] children

(** Media *)
let img ?id ?class_ ?src ?alt ?width ?height ?loading ?srcset ?sizes ?(data=[]) () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "alt" alt
    |> add_opt "width" (Option.map string_of_int width)
    |> add_opt "height" (Option.map string_of_int height)
    |> add_opt "loading" loading
    |> add_opt "srcset" srcset
    |> add_opt "sizes" sizes
    |> add_data data
  in
  element "img" ~self_closing:true attrs []

let video ?id ?class_ ?src ?(controls=false) ?(autoplay=false) ?(loop=false) ?(muted=false) ?poster ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "poster" poster
    |> add_bool "controls" controls
    |> add_bool "autoplay" autoplay
    |> add_bool "loop" loop
    |> add_bool "muted" muted
  in
  element "video" attrs children

let audio ?id ?class_ ?src ?(controls=false) ?(autoplay=false) ?(loop=false) ?(muted=false) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_bool "controls" controls
    |> add_bool "autoplay" autoplay
    |> add_bool "loop" loop
    |> add_bool "muted" muted
  in
  element "audio" attrs children

let source ?src ?type_ () =
  let attrs = [] |> add_opt "src" src |> add_opt "type" type_ in
  element "source" ~self_closing:true attrs []

let iframe ?id ?class_ ?src ?width ?height ?title () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "width" width
    |> add_opt "height" height
    |> add_opt "title" title
  in
  element "iframe" attrs []

(** {1 SVG Elements} *)

module Svg = struct
  let svg ?(xmlns=true) ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "viewBox" viewBox
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "fill" fill
    in
    let attrs = if xmlns then ("xmlns", svg_namespace) :: attrs else attrs in
    element "svg" attrs children

  let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "transform" transform
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
    in
    element "g" attrs children

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "r" r
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "circle" attrs children

  let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "rx" rx
      |> add_opt "ry" ry
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "ellipse" attrs children

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "rx" rx
      |> add_opt "ry" ry
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "rect" attrs children

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x1" x1
      |> add_opt "y1" y1
      |> add_opt "x2" x2
      |> add_opt "y2" y2
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "line" attrs children

  let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "points" points
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "polyline" attrs children

  let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "points" points
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
    in
    element "polygon" attrs children

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "d" d
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
      |> add_opt "stroke-linecap" stroke_linecap
      |> add_opt "stroke-linejoin" stroke_linejoin
      |> add_opt "fill-rule" fill_rule
      |> add_opt "clip-rule" clip_rule
    in
    element "path" attrs children

  let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "dx" dx
      |> add_opt "dy" dy
      |> add_opt "text-anchor" text_anchor
      |> add_opt "font-size" font_size
      |> add_opt "font-family" font_family
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
    in
    element "text" attrs children

  let tspan ?id ?class_ ?x ?y ?dx ?dy ?fill ?onclick:_ ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "dx" dx
      |> add_opt "dy" dy
      |> add_opt "fill" fill
    in
    element "tspan" attrs children

  let defs ?id ~children () =
    let attrs = [] |> add_opt "id" id in
    element "defs" attrs children

  let use ?id ?class_ ?href ?x ?y ?width ?height ?onclick:_ () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "href" href
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
    in
    element "use" ~self_closing:true attrs []

  let symbol ?id ?viewBox ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "viewBox" viewBox
    in
    element "symbol" attrs children

  let clipPath ?id ~children () =
    let attrs = [] |> add_opt "id" id in
    element "clipPath" attrs children

  let mask ?id ~children () =
    let attrs = [] |> add_opt "id" id in
    element "mask" attrs children

  let linearGradient ?id ?x1 ?y1 ?x2 ?y2 ?gradientUnits ?gradientTransform ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "x1" x1
      |> add_opt "y1" y1
      |> add_opt "x2" x2
      |> add_opt "y2" y2
      |> add_opt "gradientUnits" gradientUnits
      |> add_opt "gradientTransform" gradientTransform
    in
    element "linearGradient" attrs children

  let radialGradient ?id ?cx ?cy ?r ?fx ?fy ?gradientUnits ?gradientTransform ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "cx" cx
      |> add_opt "cy" cy
      |> add_opt "r" r
      |> add_opt "fx" fx
      |> add_opt "fy" fy
      |> add_opt "gradientUnits" gradientUnits
      |> add_opt "gradientTransform" gradientTransform
    in
    element "radialGradient" attrs children

  let stop ?offset ?stop_color ?stop_opacity () =
    let attrs = []
      |> add_opt "offset" offset
      |> add_opt "stop-color" stop_color
      |> add_opt "stop-opacity" stop_opacity
    in
    element "stop" ~self_closing:true attrs []

  let image ?id ?class_ ?href ?x ?y ?width ?height ?preserveAspectRatio () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "href" href
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
      |> add_opt "preserveAspectRatio" preserveAspectRatio
    in
    element "image" ~self_closing:true attrs []

  let foreignObject ?id ?class_ ?x ?y ?width ?height ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "width" width
      |> add_opt "height" height
    in
    element "foreignObject" attrs children
end

let svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ~children () =
  Svg.svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ?fill ?onclick ~children ()

let g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ~children () =
  Svg.g ?id ?class_ ?style ?transform ?fill ?stroke ?onclick ~children ()

let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.ellipse ?id ?class_ ?style ?cx ?cy ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.polyline ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children () =
  Svg.polygon ?id ?class_ ?style ?points ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?onclick ~children ()

let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ~children () =
  Svg.path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ?stroke_linecap ?stroke_linejoin ?fill_rule ?clip_rule ?onclick ~children ()

let text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ~children () =
  Svg.text_ ?id ?class_ ?style ?x ?y ?dx ?dy ?text_anchor ?font_size ?font_family ?fill ?stroke ?stroke_width ?onclick ~children ()

(** Fragment *)
let fragment nodes = Fragment nodes

(** Render document *)
let render_document ?(doctype=true) node =
  let doc = if doctype then "<!DOCTYPE html>\n" else "" in
  doc ^ to_string node

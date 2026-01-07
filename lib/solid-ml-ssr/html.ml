(** HTML element functions for server-side rendering. *)

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

(** Escape HTML special characters *)
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
          if v = "" then k  (* Boolean attribute *)
          else Printf.sprintf "%s=\"%s\"" k (escape_html v)
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

let signal_text signal =
  let key = next_hydration_key () in
  let value = string_of_int (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

let signal_text_of fmt signal =
  let key = next_hydration_key () in
  let value = fmt (Solid_ml.Signal.peek signal) in
  ReactiveText { key; value }

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
let header ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "header" attrs children

let footer ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "footer" attrs children

let main ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "main" attrs children

let nav ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "nav" attrs children

let section ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "section" attrs children

let article ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "article" attrs children

let aside ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "aside" attrs children

(** Text content *)
let div ?id ?class_ ?style ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ |> add_opt "style" style in
  element "div" attrs children

let p ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "p" attrs children

let span ?id ?class_ ?style ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ |> add_opt "style" style in
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
let h1 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h1" attrs children

let h2 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h2" attrs children

let h3 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h3" attrs children

let h4 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h4" attrs children

let h5 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h5" attrs children

let h6 ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "h6" attrs children

(** Inline text *)
let a ?id ?class_ ?href ?target ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "href" href 
    |> add_opt "target" target
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
let ul ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
  element "ul" attrs children

let ol ?id ?class_ ?start ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "start" (Option.map string_of_int start)
  in
  element "ol" attrs children

let li ?id ?class_ ~children () =
  let attrs = [] |> add_opt "id" id |> add_opt "class" class_ in
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
let form ?id ?class_ ?action ?method_ ?enctype ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "action" action
    |> add_opt "method" method_
    |> add_opt "enctype" enctype
  in
  element "form" attrs children

let input ?id ?class_ ?type_ ?name ?value ?placeholder ?(required=false) ?(disabled=false) ?(checked=false) ?(autofocus=false) () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_opt "name" name
    |> add_opt "value" value
    |> add_opt "placeholder" placeholder
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "checked" checked
    |> add_bool "autofocus" autofocus
  in
  element "input" ~self_closing:true attrs []

let textarea ?id ?class_ ?name ?placeholder ?rows ?cols ?(required=false) ?(disabled=false) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_opt "placeholder" placeholder
    |> add_opt "rows" (Option.map string_of_int rows)
    |> add_opt "cols" (Option.map string_of_int cols)
    |> add_bool "required" required
    |> add_bool "disabled" disabled
  in
  element "textarea" attrs children

let select ?id ?class_ ?name ?(required=false) ?(disabled=false) ?(multiple=false) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "name" name
    |> add_bool "required" required
    |> add_bool "disabled" disabled
    |> add_bool "multiple" multiple
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

let button ?id ?class_ ?type_ ?(disabled=false) ~children () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "type" type_
    |> add_bool "disabled" disabled
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
let img ?id ?class_ ?src ?alt ?width ?height ?loading () =
  let attrs = [] 
    |> add_opt "id" id 
    |> add_opt "class" class_
    |> add_opt "src" src
    |> add_opt "alt" alt
    |> add_opt "width" (Option.map string_of_int width)
    |> add_opt "height" (Option.map string_of_int height)
    |> add_opt "loading" loading
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
  let svg ?(xmlns=true) ?id ?class_ ?style ?viewBox ?width ?height ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "viewBox" viewBox
      |> add_opt "width" width
      |> add_opt "height" height
    in
    let attrs = if xmlns then ("xmlns", svg_namespace) :: attrs else attrs in
    element "svg" attrs children

  let g ?id ?class_ ?style ?transform ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "transform" transform
    in
    element "g" attrs children

  let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ~children () =
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
    in
    element "circle" attrs children

  let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ~children () =
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
    in
    element "rect" attrs children

  let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ~children () =
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
    in
    element "line" attrs children

  let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "d" d
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
    in
    element "path" attrs children

  let text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ~children () =
    let attrs = []
      |> add_opt "id" id
      |> add_opt "class" class_
      |> add_opt "style" style
      |> add_opt "x" x
      |> add_opt "y" y
      |> add_opt "fill" fill
      |> add_opt "stroke" stroke
      |> add_opt "stroke-width" stroke_width
    in
    element "text" attrs children
end

let svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ~children () =
  Svg.svg ?xmlns ?id ?class_ ?style ?viewBox ?width ?height ~children ()

let g ?id ?class_ ?style ?transform ~children () =
  Svg.g ?id ?class_ ?style ?transform ~children ()

let circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ~children () =
  Svg.circle ?id ?class_ ?style ?cx ?cy ?r ?fill ?stroke ?stroke_width ~children ()

let rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ~children () =
  Svg.rect ?id ?class_ ?style ?x ?y ?width ?height ?rx ?ry ?fill ?stroke ?stroke_width ~children ()

let line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ~children () =
  Svg.line ?id ?class_ ?style ?x1 ?y1 ?x2 ?y2 ?stroke ?stroke_width ~children ()

let path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ~children () =
  Svg.path ?id ?class_ ?style ?d ?fill ?stroke ?stroke_width ~children ()

let text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ~children () =
  Svg.text_ ?id ?class_ ?style ?x ?y ?fill ?stroke ?stroke_width ~children ()

(** Fragment *)
let fragment nodes = Fragment nodes

(** Render document *)
let render_document ?(doctype=true) node =
  let doc = if doctype then "<!DOCTYPE html>\n" else "" in
  doc ^ to_string node

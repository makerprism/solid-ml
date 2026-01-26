(** DOM element creation functions.
    
    These functions create actual DOM nodes. The API mirrors solid-ml-html
    so the same component patterns work on both server and client.
*)

(** {1 Core Types} *)

type node =
  | Element of Dom.element
  | Text of Dom.text_node
  | Fragment of Dom.document_fragment
  | Empty

type 'a signal = 'a Reactive_core.signal
(** A reactive signal. *)

type event = Dom.event
(** Browser DOM event. *)

type element = Dom.element
(** DOM element handle. *)

(** {1 Node Conversion} *)

val to_dom_node : node -> Dom.node
(** Convert a node to a raw DOM node *)

val append_to_element : Dom.element -> node -> unit
(** Append a node to an element *)

val append_to_fragment : Dom.document_fragment -> node -> unit
(** Append a node to a fragment *)

(** {1 Text Content} *)

val text : string -> node
val int : int -> node
val float : float -> node
val empty : node

(** {1 Reactive Text} *)

val reactive_text : int signal -> node
(** Reactive text from an int signal. *)

val reactive_text_of : ('a -> string) -> 'a signal -> node
(** Reactive text with custom formatter. *)

val reactive_text_string : string signal -> node
(** Reactive text from a string signal. *)

(** {1 Fragment} *)

val fragment : node list -> node
(** Create a fragment from a list of nodes *)

(** {1 Compiled Templates (Internal)}

    Compiled templates are an internal mechanism used by the MLX + template PPX
    pipeline. Application code should normally:

    - create DOM with the [Html.*] constructors
    - hydrate SSR markup via {!Solid_ml_browser.Render.hydrate}

    This module remains part of the interface for generated code, but it is not
    intended to be called directly by applications.
*)

module Internal_template : Solid_ml_template_runtime.TEMPLATE
  with type node := node
   and type event := event
   and type element = Dom.element

(** {1 Document Root} *)

val html : ?lang:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val head : ?attrs:(string * string) list -> children:node list -> unit -> node
val body : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val title : ?attrs:(string * string) list -> children:node list -> unit -> node
val meta : ?charset:string -> ?name:string -> ?content:string -> ?attrs:(string * string) list -> unit -> node
val link : ?rel:string -> ?href:string -> ?attrs:(string * string) list -> unit -> node
val script : ?src:string -> ?type_:string -> ?defer:bool -> ?async:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {1 Document Structure} *)

val div : ?id:string -> ?class_:string -> ?style:string -> ?role:string -> ?aria_label:string -> ?aria_hidden:bool -> ?tabindex:int ->
  ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val span : ?id:string -> ?class_:string -> ?style:string -> ?role:string -> ?aria_label:string -> ?aria_hidden:bool ->
  ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val p : ?id:string -> ?class_:string -> ?role:string ->
  ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val pre : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val code : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Headings} *)

val h1 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h2 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h3 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h4 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h5 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h6 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Sectioning} *)

val header : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val footer : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val main : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val nav : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val section : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?aria_labelledby:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val article : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val aside : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val figure : ?id:string -> ?class_:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val figcaption : ?id:string -> ?class_:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val address : ?id:string -> ?class_:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val details : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val summary : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Inline Elements} *)

val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> ?rel:string -> ?download:string -> ?hreflang:string -> ?tabindex:int ->
  ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val strong : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val em : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val b : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val i : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val u : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val s : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val small : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val mark : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val sup : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val sub : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val cite : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val q : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val abbr : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val data : ?id:string -> ?class_:string -> ?value:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val time : ?id:string -> ?class_:string -> ?datetime:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val kbd : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val samp : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val var : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val del : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val ins : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val blockquote : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val br : ?attrs:(string * string) list -> unit -> node
val hr : ?class_:string -> ?attrs:(string * string) list -> unit -> node

(** {2 Lists} *)

val ul : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val ol : ?id:string -> ?class_:string -> ?start:int -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val dl : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val dt : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val dd : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val li : ?id:string -> ?class_:string -> ?role:string -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Tables} *)

val table : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val caption : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val colgroup : ?attrs:(string * string) list -> children:node list -> unit -> node
val col : ?span:int -> ?attrs:(string * string) list -> unit -> node
val thead : ?attrs:(string * string) list -> children:node list -> unit -> node
val tbody : ?attrs:(string * string) list -> children:node list -> unit -> node
val tfoot : ?attrs:(string * string) list -> children:node list -> unit -> node
val tr : ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val th : ?class_:string -> ?scope:string -> ?colspan:int -> ?rowspan:int -> ?attrs:(string * string) list -> children:node list -> unit -> node
val td : ?class_:string -> ?colspan:int -> ?rowspan:int -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Forms} *)

val form : ?id:string -> ?class_:string -> ?action:string -> ?method_:string ->
  ?enctype:string -> ?onsubmit:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node

val input : ?id:string -> ?class_:string -> ?type_:string -> ?name:string ->
  ?value:string -> ?placeholder:string -> ?accept:string -> ?min:string -> ?max:string -> ?step:string ->
  ?required:bool -> ?disabled:bool -> ?checked:bool -> ?autofocus:bool -> ?readonly:bool ->
  ?tabindex:int -> ?oninput:(event -> unit) -> ?onchange:(event -> unit) ->
  ?onkeydown:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> ?children:node list -> unit -> node

val textarea : ?id:string -> ?class_:string -> ?name:string -> ?placeholder:string ->
  ?rows:int -> ?cols:int -> ?required:bool -> ?disabled:bool -> ?autofocus:bool -> ?readonly:bool ->
  ?tabindex:int -> ?oninput:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val select : ?id:string -> ?class_:string -> ?name:string -> ?required:bool ->
  ?disabled:bool -> ?multiple:bool -> ?autofocus:bool -> ?tabindex:int -> ?onchange:(event -> unit) ->
  ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

val option : ?value:string -> ?selected:bool -> ?disabled:bool -> ?attrs:(string * string) list ->
  children:node list -> unit -> node
val optgroup : ?label:string -> ?disabled:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node

val label : ?id:string -> ?class_:string -> ?for_:string -> ?attrs:(string * string) list ->
  children:node list -> unit -> node

val button : ?id:string -> ?class_:string -> ?type_:string -> ?disabled:bool ->
  ?tabindex:int -> ?aria_label:string -> ?aria_expanded:bool -> ?aria_controls:string -> ?aria_haspopup:bool ->
  ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val output : ?id:string -> ?class_:string -> ?for_:string -> ?name:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val progress : ?id:string -> ?class_:string -> ?value:string -> ?max:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val meter : ?id:string -> ?class_:string -> ?value:string -> ?min:string -> ?max:string -> ?low:string -> ?high:string -> ?optimum:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val fieldset : ?id:string -> ?class_:string -> ?disabled:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node
val legend : ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Media} *)

val picture : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val img : ?id:string -> ?class_:string -> ?src:string -> ?alt:string ->
  ?width:int -> ?height:int -> ?loading:string -> ?srcset:string -> ?sizes:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> unit -> node
val source : ?src:string -> ?type_:string -> ?attrs:(string * string) list -> unit -> node
val track : ?kind:string -> ?src:string -> ?srclang:string -> ?label:string -> ?attrs:(string * string) list -> unit -> node
val video : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> ?poster:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val audio : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {1 Portal} *)

val portal : ?target:element -> ?is_svg:bool -> children:node -> unit -> node

(** {1 SVG Elements} *)

module Svg : sig
  (** Browser SVG helpers using namespaced DOM creation. *)
  val svg : ?xmlns:bool -> ?id:string -> ?class_:string -> ?style:string -> ?viewBox:string -> ?width:string -> ?height:string -> ?fill:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val g : ?id:string -> ?class_:string -> ?style:string -> ?transform:string -> ?fill:string -> ?stroke:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val circle : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
    ?cy:string -> ?r:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
    ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val ellipse : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
    ?cy:string -> ?rx:string -> ?ry:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
    ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val rect : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
    ?y:string -> ?width:string -> ?height:string -> ?rx:string -> ?ry:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val line : ?id:string -> ?class_:string -> ?style:string -> ?x1:string ->
    ?y1:string -> ?x2:string -> ?y2:string -> ?stroke:string -> ?stroke_width:string ->
    ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val polyline : ?id:string -> ?class_:string -> ?style:string -> ?points:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
    ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val polygon : ?id:string -> ?class_:string -> ?style:string -> ?points:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
    ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val path : ?id:string -> ?class_:string -> ?style:string -> ?d:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
    ?fill_rule:string -> ?clip_rule:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list ->
    children:node list -> unit -> node
  val text_ : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
    ?y:string -> ?dx:string -> ?dy:string -> ?text_anchor:string -> ?font_size:string -> ?font_family:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val tspan : ?id:string -> ?class_:string -> ?x:string -> ?y:string -> ?dx:string -> ?dy:string ->
    ?fill:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val defs : ?id:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val use : ?id:string -> ?class_:string -> ?href:string -> ?x:string -> ?y:string ->
    ?width:string -> ?height:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> unit -> node
  val symbol : ?id:string -> ?viewBox:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val clipPath : ?id:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val mask : ?id:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val linearGradient : ?id:string -> ?x1:string -> ?y1:string -> ?x2:string -> ?y2:string ->
    ?gradientUnits:string -> ?gradientTransform:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val radialGradient : ?id:string -> ?cx:string -> ?cy:string -> ?r:string -> ?fx:string -> ?fy:string ->
    ?gradientUnits:string -> ?gradientTransform:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val stop : ?offset:string -> ?stop_color:string -> ?stop_opacity:string -> ?attrs:(string * string) list -> unit -> node
  val image : ?id:string -> ?class_:string -> ?href:string -> ?x:string -> ?y:string ->
    ?width:string -> ?height:string -> ?preserveAspectRatio:string -> ?attrs:(string * string) list -> unit -> node
  val foreignObject : ?id:string -> ?class_:string -> ?x:string -> ?y:string ->
    ?width:string -> ?height:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
end

val svg : ?xmlns:bool -> ?id:string -> ?class_:string -> ?style:string -> ?viewBox:string ->
  ?width:string -> ?height:string -> ?fill:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val g : ?id:string -> ?class_:string -> ?style:string -> ?transform:string ->
  ?fill:string -> ?stroke:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val circle : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
  ?cy:string -> ?r:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
  ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val ellipse : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
  ?cy:string -> ?rx:string -> ?ry:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
  ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val rect : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
  ?y:string -> ?width:string -> ?height:string -> ?rx:string -> ?ry:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) ->
  ?attrs:(string * string) list -> children:node list -> unit -> node
val line : ?id:string -> ?class_:string -> ?style:string -> ?x1:string ->
  ?y1:string -> ?x2:string -> ?y2:string -> ?stroke:string -> ?stroke_width:string ->
  ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val polyline : ?id:string -> ?class_:string -> ?style:string -> ?points:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
  ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val polygon : ?id:string -> ?class_:string -> ?style:string -> ?points:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
  ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val path : ?id:string -> ?class_:string -> ?style:string -> ?d:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string ->
  ?fill_rule:string -> ?clip_rule:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list ->
  children:node list -> unit -> node
val text_ : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
  ?y:string -> ?dx:string -> ?dy:string -> ?text_anchor:string -> ?font_size:string -> ?font_family:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string ->
  ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {1 Node Access} *)

val get_element : node -> Dom.element option
(** Get the underlying DOM element *)

val get_text_node : node -> Dom.text_node option
(** Get the underlying DOM text node *)

(** HTML element functions for server-side rendering.

    These functions generate HTML strings from element descriptions.
    They are designed to work with MLX JSX-like syntax.

    {[
      (* MLX transforms this: *)
      <div class_="container">
        <p>"Hello, world!"</p>
      </div>

      (* Into this: *)
      div ~class_:"container" ~children:[
        p ~children:[text "Hello, world!"] ()
      ] ()
    ]}
*)

(** {1 Core Types} *)

(** An HTML node (element or text). *)
type node

(** Event type stub for unified SSR/browser interface.
    On SSR, events are never instantiated - handlers are ignored. *)
type event = unit

type 'a signal = 'a Solid_ml.Signal.t
(** A reactive signal type for unified SSR/browser components. *)

(** Convert a node to its HTML string representation. *)
val to_string : node -> string

(** {1 Text Content} *)

(** Create a text node. Text is automatically HTML-escaped. *)
val text : string -> node

(** Create a text node from an integer. *)
val int : int -> node

(** Create a text node from a float. *)
val float : float -> node

(** Create a raw HTML node (not escaped - use with caution). *)
val raw : string -> node

(** {1 Reactive Text}

    These functions create reactive text nodes with hydration markers.
    On SSR, they render the current signal value wrapped in markers
    that enable client-side hydration. *)

(** Create a reactive text node from an int signal. *)
val reactive_text : int signal -> node

(** Reactive text with custom formatter. *)
val reactive_text_of : ('a -> string) -> 'a signal -> node

(** Reactive text from a string signal. *)
val reactive_text_string : string signal -> node

(** {1 Deprecated Aliases} *)

(** @deprecated Use [reactive_text] instead. *)
val signal_text : int signal -> node

(** @deprecated Use [reactive_text_of] instead. *)
val signal_text_of : ('a -> string) -> 'a signal -> node

(** {1 HTML Elements} *)

(** Common attributes for all elements. *)
type common_attrs = {
  id : string option;
  class_ : string option;
  style : string option;
  title : string option;
  data : (string * string) list;
}

(** Default empty attributes. *)
val no_attrs : common_attrs

(** {2 Document Structure} *)

val html : ?lang:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val head : ?attrs:(string * string) list -> children:node list -> unit -> node
val body : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val title : ?attrs:(string * string) list -> children:node list -> unit -> node
val meta : ?charset:string -> ?name:string -> ?property:string -> ?content:string -> ?attrs:(string * string) list -> unit -> node
val link : ?rel:string -> ?href:string -> ?hreflang:string -> ?type_:string -> ?attrs:(string * string) list -> unit -> node
val script : ?src:string -> ?type_:string -> ?defer:bool -> ?async:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Content Sectioning} *)

val header : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val footer : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val main : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val nav : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val section : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?aria_labelledby:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val article : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val aside : ?id:string -> ?class_:string -> ?role:string -> ?aria_label:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Text Content} *)

val div : ?id:string -> ?class_:string -> ?style:string -> ?role:string -> ?aria_label:string -> ?aria_hidden:bool -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val p : ?id:string -> ?class_:string -> ?role:string -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val span : ?id:string -> ?class_:string -> ?style:string -> ?role:string -> ?aria_label:string -> ?aria_hidden:bool -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val pre : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val code : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val blockquote : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Headings} *)

val h1 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h2 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h3 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h4 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h5 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val h6 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Inline Text} *)

val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> ?rel:string -> ?download:string -> ?hreflang:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val strong : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val em : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val br : ?attrs:(string * string) list -> unit -> node
val hr : ?class_:string -> ?attrs:(string * string) list -> unit -> node

(** {2 Lists} *)

val ul : ?id:string -> ?class_:string -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val ol : ?id:string -> ?class_:string -> ?start:int -> ?role:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val li : ?id:string -> ?class_:string -> ?role:string -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Tables} *)

val table : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val thead : ?attrs:(string * string) list -> children:node list -> unit -> node
val tbody : ?attrs:(string * string) list -> children:node list -> unit -> node
val tfoot : ?attrs:(string * string) list -> children:node list -> unit -> node
val tr : ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val th : ?class_:string -> ?scope:string -> ?colspan:int -> ?rowspan:int -> ?attrs:(string * string) list -> children:node list -> unit -> node
val td : ?class_:string -> ?colspan:int -> ?rowspan:int -> ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Forms} *)

val form : ?id:string -> ?class_:string -> ?action:string -> ?method_:string -> ?enctype:string -> ?onsubmit:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
val input : ?id:string -> ?class_:string -> ?type_:string -> ?name:string -> ?value:string -> ?placeholder:string -> ?accept:string -> ?min:string -> ?max:string -> ?step:string -> ?required:bool -> ?disabled:bool -> ?checked:bool -> ?autofocus:bool -> ?readonly:bool -> ?tabindex:int -> ?oninput:(event -> unit) -> ?onchange:(event -> unit) -> ?onkeydown:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> ?children:node list -> unit -> node
val textarea : ?id:string -> ?class_:string -> ?name:string -> ?placeholder:string -> ?rows:int -> ?cols:int -> ?required:bool -> ?disabled:bool -> ?autofocus:bool -> ?readonly:bool -> ?tabindex:int -> ?oninput:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val select : ?id:string -> ?class_:string -> ?name:string -> ?required:bool -> ?disabled:bool -> ?multiple:bool -> ?autofocus:bool -> ?tabindex:int -> ?onchange:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val option : ?value:string -> ?selected:bool -> ?disabled:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node
val label : ?id:string -> ?class_:string -> ?for_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val button : ?id:string -> ?class_:string -> ?type_:string -> ?disabled:bool -> ?tabindex:int -> ?aria_label:string -> ?aria_expanded:bool -> ?aria_controls:string -> ?aria_haspopup:bool -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
val fieldset : ?id:string -> ?class_:string -> ?disabled:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node
val legend : ?attrs:(string * string) list -> children:node list -> unit -> node

(** {2 Media} *)

val img : ?id:string -> ?class_:string -> ?src:string -> ?alt:string -> ?width:int -> ?height:int -> ?loading:string -> ?srcset:string -> ?sizes:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> unit -> node
val video : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> ?poster:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
val audio : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> ?attrs:(string * string) list -> children:node list -> unit -> node
val source : ?src:string -> ?type_:string -> ?attrs:(string * string) list -> unit -> node
val iframe : ?id:string -> ?class_:string -> ?src:string -> ?width:string -> ?height:string -> ?title:string -> ?attrs:(string * string) list -> unit -> node

(** {2 SVG Elements} *)

module Svg : sig
  (** Server-side SVG helpers.
      The [~xmlns] flag defaults to [true]. Set [~xmlns:false] when rendering
      nested SVGs to avoid duplicate namespace attributes. *)
  val svg : ?xmlns:bool -> ?id:string -> ?class_:string -> ?style:string ->
    ?viewBox:string -> ?width:string -> ?height:string -> ?fill:string -> ?onclick:(event -> unit) ->
    ?attrs:(string * string) list -> children:node list -> unit -> node
  val g : ?id:string -> ?class_:string -> ?style:string -> ?transform:string ->
    ?fill:string -> ?stroke:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val circle : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
    ?cy:string -> ?r:string -> ?fill:string -> ?stroke:string ->
    ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val ellipse : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
    ?cy:string -> ?rx:string -> ?ry:string -> ?fill:string -> ?stroke:string ->
    ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val rect : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
    ?y:string -> ?width:string -> ?height:string -> ?rx:string -> ?ry:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) ->
    ?attrs:(string * string) list -> children:node list -> unit -> node
  val line : ?id:string -> ?class_:string -> ?style:string -> ?x1:string ->
    ?y1:string -> ?x2:string -> ?y2:string -> ?stroke:string ->
    ?stroke_width:string -> ?stroke_linecap:string -> ?stroke_linejoin:string -> ?onclick:(event -> unit) -> ?attrs:(string * string) list -> children:node list -> unit -> node
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

val svg : ?xmlns:bool -> ?id:string -> ?class_:string -> ?style:string ->
  ?viewBox:string -> ?width:string -> ?height:string -> ?fill:string -> ?onclick:(event -> unit) ->
  ?attrs:(string * string) list -> children:node list -> unit -> node
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

(** {2 Other} *)

val fragment : node list -> node
val empty : node

(** {1 Compiled Templates} *)

type template_element
(** Element handle used by compiled templates.

    On SSR this is an internal handle that allows [Template.set_attr] to affect
    the rendered output. *)

module Internal_template : Solid_ml_template_runtime.TEMPLATE
  with type node := node
   and type event := event
   and type element = template_element

(** {1 Rendering} *)

(** Render a complete HTML document. *)
val render_document : ?doctype:bool -> node -> string

(** {1 Internal} *)

(** Reset hydration key counter. Called by Render module between renders. *)
val reset_hydration_keys : unit -> unit

(** Minimal environment interface used by the template compiler.

    This lives in [solid-ml-template-runtime] so both SSR and browser packages can
    expose a canonical environment without introducing a dependency on the core
    [solid-ml] package.

    The template compiler only needs:
    - a signal type with basic operations
    - an Html.Template backend for instantiation/binding
    - Effect.create for fine-grained reactive updates
    - Owner.on_cleanup for disposal (events, conditional mounts, lists)

    Note: this interface is intentionally smaller than [Solid_ml.Component.COMPONENT_ENV]
    and does not depend on [Solid_ml.Html_intf.S]. Compiled templates should not
    need to call element constructors at runtime; they instantiate precompiled
    templates via [Html.Template].
*)

module type SIGNAL = sig
  type 'a t

  val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  val get : 'a t -> 'a
  val peek : 'a t -> 'a
  val update : 'a t -> ('a -> 'a) -> unit
end

module type HTML = sig
  type node
  type event
  type 'a signal

  (** {2 Text Content} *)

  val text : string -> node
  val int : int -> node
  val float : float -> node
  val fragment : node list -> node
  val empty : node

  (** {2 Reactive Text} *)

  val reactive_text : int signal -> node
  val reactive_text_of : ('a -> string) -> 'a signal -> node
  val reactive_text_string : string signal -> node

  (** {2 Document Structure} *)

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

  (** {2 Inline Elements} *)

  val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> ?rel:string -> ?download:string -> ?hreflang:string -> ?tabindex:int ->
    ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

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

  val label : ?id:string -> ?class_:string -> ?for_:string -> ?attrs:(string * string) list ->
    children:node list -> unit -> node

  val button : ?id:string -> ?class_:string -> ?type_:string -> ?disabled:bool ->
    ?tabindex:int -> ?aria_label:string -> ?aria_expanded:bool -> ?aria_controls:string -> ?aria_haspopup:bool ->
    ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

  (** {2 Media} *)

  val img : ?id:string -> ?class_:string -> ?src:string -> ?alt:string ->
    ?width:int -> ?height:int -> ?loading:string -> ?srcset:string -> ?sizes:string -> ?data:(string * string) list -> ?attrs:(string * string) list -> unit -> node

  (** {2 SVG Elements} *)

  module Svg : sig
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
  end

  module Internal_template : Template_intf.TEMPLATE
    with type node := node
     and type event := event
end

module type TPL = sig
  type 'a t

  val text : (unit -> string) -> 'a t
  val text_value : string -> 'a t
  val attr : name:string -> (unit -> string) -> 'a t
  val attr_opt : name:string -> (unit -> string option) -> 'a t
  val class_list : (unit -> (string * bool) list) -> 'a t
  val on : event:string -> ('ev -> unit) -> ('ev -> unit) t
  val bind_input : signal:(unit -> string) -> setter:(string -> unit) -> 'a t
  val bind_checkbox : signal:(unit -> bool) -> setter:(bool -> unit) -> 'a t
  val bind_select : signal:(unit -> string) -> setter:(string -> unit) -> 'a t
  val nodes : (unit -> 'a) -> 'a t
  val show : when_:(unit -> bool) -> (unit -> 'a) -> 'a t
  val show_when : when_:(unit -> bool) -> (unit -> 'a) -> 'a t
  val if_ : when_:(unit -> bool) -> then_:(unit -> 'a) -> else_:(unit -> 'a) -> 'a t
  val switch : match_:(unit -> 'a) -> cases:(('a -> bool) * (unit -> 'b)) array -> 'b t
  val each_keyed : items:(unit -> 'a list) -> key:('a -> string) -> render:('a -> 'b) -> 'b t
  val each : items:(unit -> 'a list) -> render:('a -> 'b) -> 'b t
  val eachi : items:(unit -> 'a list) -> render:(int -> 'a -> 'b) -> 'b t
  val each_indexed :
    items:(unit -> 'a list)
    -> render:(index:(unit -> int) -> item:(unit -> 'a) -> 'b)
    -> 'b t
  val unreachable : 'a t -> 'a
end

module type TEMPLATE_ENV = sig
  module Signal : SIGNAL
  type 'a signal = 'a Signal.t

  module Html : HTML with type 'a signal = 'a Signal.t

  module Tpl : TPL

  module Effect : sig
    val create : (unit -> unit) -> unit
    val create_with_cleanup : (unit -> (unit -> unit)) -> unit
  end

  module Owner : sig
    val on_cleanup : (unit -> unit) -> unit

    val run_with_owner : (unit -> 'a) -> 'a * (unit -> unit)
    (** Run a function under a fresh owner.

        Returns the function result and a disposer that cleans up any effects,
        event handlers, and other resources registered under that owner. *)
  end
end

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

(** {1 Document Structure} *)

val div : ?id:string -> ?class_:string -> ?style:string -> 
  ?onclick:(event -> unit) -> children:node list -> unit -> node

val span : ?id:string -> ?class_:string -> ?style:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node

val p : ?id:string -> ?class_:string -> 
  ?onclick:(event -> unit) -> children:node list -> unit -> node

val pre : ?id:string -> ?class_:string -> children:node list -> unit -> node
val code : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {1 Headings} *)

val h1 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val h2 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val h3 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val h4 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val h5 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val h6 : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node

(** {1 Sectioning} *)

val header : ?id:string -> ?class_:string -> children:node list -> unit -> node
val footer : ?id:string -> ?class_:string -> children:node list -> unit -> node
val main : ?id:string -> ?class_:string -> children:node list -> unit -> node
val nav : ?id:string -> ?class_:string -> children:node list -> unit -> node
val section : ?id:string -> ?class_:string -> children:node list -> unit -> node
val article : ?id:string -> ?class_:string -> children:node list -> unit -> node
val aside : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {1 Inline Elements} *)

val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node

val strong : ?id:string -> ?class_:string -> children:node list -> unit -> node
val em : ?id:string -> ?class_:string -> children:node list -> unit -> node
val br : unit -> node
val hr : ?class_:string -> unit -> node

(** {1 Lists} *)

val ul : ?id:string -> ?class_:string -> children:node list -> unit -> node
val ol : ?id:string -> ?class_:string -> ?start:int -> children:node list -> unit -> node
val li : ?id:string -> ?class_:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node

(** {1 Tables} *)

val table : ?id:string -> ?class_:string -> children:node list -> unit -> node
val thead : children:node list -> unit -> node
val tbody : children:node list -> unit -> node
val tfoot : children:node list -> unit -> node
val tr : ?class_:string -> children:node list -> unit -> node
val th : ?class_:string -> ?scope:string -> ?colspan:int -> ?rowspan:int -> children:node list -> unit -> node
val td : ?class_:string -> ?colspan:int -> ?rowspan:int -> children:node list -> unit -> node

(** {1 Forms} *)

val form : ?id:string -> ?class_:string -> ?action:string -> ?method_:string ->
  ?enctype:string -> ?onsubmit:(event -> unit) -> children:node list -> unit -> node

val input : ?id:string -> ?class_:string -> ?type_:string -> ?name:string ->
  ?value:string -> ?placeholder:string -> ?required:bool -> ?disabled:bool ->
  ?checked:bool -> ?autofocus:bool -> ?oninput:(event -> unit) -> ?onchange:(event -> unit) ->
  ?onkeydown:(event -> unit) -> unit -> node

val textarea : ?id:string -> ?class_:string -> ?name:string -> ?placeholder:string ->
  ?rows:int -> ?cols:int -> ?required:bool -> ?disabled:bool ->
  ?oninput:(event -> unit) -> children:node list -> unit -> node

val select : ?id:string -> ?class_:string -> ?name:string -> ?required:bool ->
  ?disabled:bool -> ?multiple:bool -> ?onchange:(event -> unit) ->
  children:node list -> unit -> node

val option : ?value:string -> ?selected:bool -> ?disabled:bool ->
  children:node list -> unit -> node

val label : ?id:string -> ?class_:string -> ?for_:string ->
  children:node list -> unit -> node

val button : ?id:string -> ?class_:string -> ?type_:string -> ?disabled:bool ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node

(** {1 Media} *)

val img : ?id:string -> ?class_:string -> ?src:string -> ?alt:string ->
  ?width:int -> ?height:int -> ?loading:string -> unit -> node

(** {1 SVG Elements} *)

module Svg : sig
  (** Browser SVG helpers using namespaced DOM creation. *)
  val svg : ?id:string -> ?class_:string -> ?style:string -> ?viewBox:string ->
    ?width:string -> ?height:string -> ?onclick:(event -> unit) ->
    children:node list -> unit -> node
  val g : ?id:string -> ?class_:string -> ?style:string -> ?transform:string ->
    ?onclick:(event -> unit) -> children:node list -> unit -> node
  val circle : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
    ?cy:string -> ?r:string -> ?fill:string -> ?stroke:string ->
    ?stroke_width:string -> ?onclick:(event -> unit) ->
    children:node list -> unit -> node
  val rect : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
    ?y:string -> ?width:string -> ?height:string -> ?rx:string -> ?ry:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string ->
    ?onclick:(event -> unit) -> children:node list -> unit -> node
  val line : ?id:string -> ?class_:string -> ?style:string -> ?x1:string ->
    ?y1:string -> ?x2:string -> ?y2:string -> ?stroke:string ->
    ?stroke_width:string -> ?onclick:(event -> unit) ->
    children:node list -> unit -> node
  val path : ?id:string -> ?class_:string -> ?style:string -> ?d:string ->
    ?fill:string -> ?stroke:string -> ?stroke_width:string ->
    ?onclick:(event -> unit) -> children:node list -> unit -> node
  val text_ : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
    ?y:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
    ?onclick:(event -> unit) -> children:node list -> unit -> node
end

val svg : ?id:string -> ?class_:string -> ?style:string -> ?viewBox:string ->
  ?width:string -> ?height:string -> ?onclick:(event -> unit) -> children:node list -> unit -> node
val g : ?id:string -> ?class_:string -> ?style:string -> ?transform:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node
val circle : ?id:string -> ?class_:string -> ?style:string -> ?cx:string ->
  ?cy:string -> ?r:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node
val rect : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
  ?y:string -> ?width:string -> ?height:string -> ?rx:string -> ?ry:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?onclick:(event -> unit) ->
  children:node list -> unit -> node
val line : ?id:string -> ?class_:string -> ?style:string -> ?x1:string ->
  ?y1:string -> ?x2:string -> ?y2:string -> ?stroke:string -> ?stroke_width:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node
val path : ?id:string -> ?class_:string -> ?style:string -> ?d:string ->
  ?fill:string -> ?stroke:string -> ?stroke_width:string -> ?onclick:(event -> unit) ->
  children:node list -> unit -> node
val text_ : ?id:string -> ?class_:string -> ?style:string -> ?x:string ->
  ?y:string -> ?fill:string -> ?stroke:string -> ?stroke_width:string ->
  ?onclick:(event -> unit) -> children:node list -> unit -> node

(** {1 Node Access} *)

val get_element : node -> Dom.element option
(** Get the underlying DOM element *)

val get_text_node : node -> Dom.text_node option
(** Get the underlying DOM text node *)

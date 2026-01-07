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

(** Create a reactive text node from a signal.
    On the server, this renders the current value.
    The returned node will have a hydration marker for client-side updates. *)
val signal_text : int Solid_ml.Signal.t -> node

(** Generic signal to text with custom formatter. *)
val signal_text_of : ('a -> string) -> 'a Solid_ml.Signal.t -> node

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

val html : ?lang:string -> children:node list -> unit -> node
val head : children:node list -> unit -> node
val body : ?id:string -> ?class_:string -> children:node list -> unit -> node
val title : children:node list -> unit -> node
val meta : ?charset:string -> ?name:string -> ?property:string -> ?content:string -> unit -> node
val link : ?rel:string -> ?href:string -> ?hreflang:string -> ?type_:string -> unit -> node
val script : ?src:string -> ?type_:string -> ?defer:bool -> ?async:bool -> children:node list -> unit -> node

(** {2 Content Sectioning} *)

val header : ?id:string -> ?class_:string -> children:node list -> unit -> node
val footer : ?id:string -> ?class_:string -> children:node list -> unit -> node
val main : ?id:string -> ?class_:string -> children:node list -> unit -> node
val nav : ?id:string -> ?class_:string -> children:node list -> unit -> node
val section : ?id:string -> ?class_:string -> children:node list -> unit -> node
val article : ?id:string -> ?class_:string -> children:node list -> unit -> node
val aside : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {2 Text Content} *)

val div : ?id:string -> ?class_:string -> ?style:string -> children:node list -> unit -> node
val p : ?id:string -> ?class_:string -> children:node list -> unit -> node
val span : ?id:string -> ?class_:string -> ?style:string -> children:node list -> unit -> node
val pre : ?id:string -> ?class_:string -> children:node list -> unit -> node
val code : ?id:string -> ?class_:string -> children:node list -> unit -> node
val blockquote : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {2 Headings} *)

val h1 : ?id:string -> ?class_:string -> children:node list -> unit -> node
val h2 : ?id:string -> ?class_:string -> children:node list -> unit -> node
val h3 : ?id:string -> ?class_:string -> children:node list -> unit -> node
val h4 : ?id:string -> ?class_:string -> children:node list -> unit -> node
val h5 : ?id:string -> ?class_:string -> children:node list -> unit -> node
val h6 : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {2 Inline Text} *)

val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> children:node list -> unit -> node
val strong : ?id:string -> ?class_:string -> children:node list -> unit -> node
val em : ?id:string -> ?class_:string -> children:node list -> unit -> node
val br : unit -> node
val hr : ?class_:string -> unit -> node

(** {2 Lists} *)

val ul : ?id:string -> ?class_:string -> children:node list -> unit -> node
val ol : ?id:string -> ?class_:string -> ?start:int -> children:node list -> unit -> node
val li : ?id:string -> ?class_:string -> children:node list -> unit -> node

(** {2 Tables} *)

val table : ?id:string -> ?class_:string -> children:node list -> unit -> node
val thead : children:node list -> unit -> node
val tbody : children:node list -> unit -> node
val tfoot : children:node list -> unit -> node
val tr : ?class_:string -> children:node list -> unit -> node
val th : ?class_:string -> ?scope:string -> ?colspan:int -> ?rowspan:int -> children:node list -> unit -> node
val td : ?class_:string -> ?colspan:int -> ?rowspan:int -> children:node list -> unit -> node

(** {2 Forms} *)

val form : ?id:string -> ?class_:string -> ?action:string -> ?method_:string -> ?enctype:string -> children:node list -> unit -> node
val input : ?id:string -> ?class_:string -> ?type_:string -> ?name:string -> ?value:string -> ?placeholder:string -> ?required:bool -> ?disabled:bool -> ?checked:bool -> ?autofocus:bool -> unit -> node
val textarea : ?id:string -> ?class_:string -> ?name:string -> ?placeholder:string -> ?rows:int -> ?cols:int -> ?required:bool -> ?disabled:bool -> children:node list -> unit -> node
val select : ?id:string -> ?class_:string -> ?name:string -> ?required:bool -> ?disabled:bool -> ?multiple:bool -> children:node list -> unit -> node
val option : ?value:string -> ?selected:bool -> ?disabled:bool -> children:node list -> unit -> node
val label : ?id:string -> ?class_:string -> ?for_:string -> children:node list -> unit -> node
val button : ?id:string -> ?class_:string -> ?type_:string -> ?disabled:bool -> children:node list -> unit -> node
val fieldset : ?id:string -> ?class_:string -> ?disabled:bool -> children:node list -> unit -> node
val legend : children:node list -> unit -> node

(** {2 Media} *)

val img : ?id:string -> ?class_:string -> ?src:string -> ?alt:string -> ?width:int -> ?height:int -> ?loading:string -> unit -> node
val video : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> ?poster:string -> children:node list -> unit -> node
val audio : ?id:string -> ?class_:string -> ?src:string -> ?controls:bool -> ?autoplay:bool -> ?loop:bool -> ?muted:bool -> children:node list -> unit -> node
val source : ?src:string -> ?type_:string -> unit -> node
val iframe : ?id:string -> ?class_:string -> ?src:string -> ?width:string -> ?height:string -> ?title:string -> unit -> node

(** {2 Other} *)

val fragment : node list -> node

(** {1 Rendering} *)

(** Render a complete HTML document. *)
val render_document : ?doctype:bool -> node -> string

(** {1 Internal} *)

(** Reset hydration key counter. Called by Render module between renders. *)
val reset_hydration_keys : unit -> unit

(** Html interface for unified SSR/browser components.

    This module defines a shared interface that both solid-ml-ssr and
    solid-ml-browser Html modules satisfy, enabling components to be
    written once and compiled for both targets.

    {[
      (* A component that works on both SSR and browser *)
      module Counter (Env : Component.COMPONENT_ENV) = struct
        open Env

        let render ~initial () =
          let count, set_count = Signal.create initial in
          Html.div ~children:[
            Html.p ~children:[Html.reactive_text count] ();
            Html.button ~onclick:(fun _ -> Signal.update count succ)
              ~children:[Html.text "+"] ()
          ] ()
      end
    ]}
*)

(** {1 Html Module Signature} *)

module type S = sig
  (** {2 Core Types} *)

  type node
  (** An HTML node (element, text, or fragment) *)

  type 'a signal
  (** A reactive signal. On SSR this is [Solid_ml.Signal.t],
      on browser this is [Reactive.Signal.t]. *)

  type event
  (** Event type. On the browser, this is [Dom.event]. On the server,
      this is a stub type that is never instantiated.
      Event handlers are silently ignored on SSR. *)

  (** {2 Text Content} *)

  val text : string -> node
  (** Create a text node. Text is HTML-escaped. *)

  val int : int -> node
  (** Create a text node from an integer. *)

  val float : float -> node
  (** Create a text node from a float. *)

  val fragment : node list -> node
  (** Create a fragment containing multiple nodes. *)

  (** {2 Reactive Text}

      These functions create text nodes that update reactively.
      On SSR, they render the current signal value with hydration markers.
      On browser, they create reactive bindings that update when signals change. *)

  val reactive_text : int signal -> node
  (** Reactive text from an int signal. *)

  val reactive_text_of : ('a -> string) -> 'a signal -> node
  (** Reactive text with custom formatter. *)

  val reactive_text_string : string signal -> node
  (** Reactive text from a string signal. *)

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
    ?onkeydown:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> unit -> node
  
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
end

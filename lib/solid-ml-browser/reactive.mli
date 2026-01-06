(** Reactive DOM primitives.
    
    These functions create reactive bindings between signals and DOM nodes.
    All bindings register cleanup with the current Owner.
    
    This module uses a browser-optimized reactive core that doesn't require
    Domain-local storage (since JavaScript is single-threaded).
*)

(** {1 Reactive Primitives} *)

module Signal : sig
  type 'a t
  val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  val get : 'a t -> 'a
  val set : 'a t -> 'a -> unit
  val update : 'a t -> ('a -> 'a) -> unit
  val peek : 'a t -> 'a
end

module Effect : sig
  val create : (unit -> unit) -> unit
  val create_with_cleanup : (unit -> (unit -> unit)) -> unit
  val untrack : (unit -> 'a) -> 'a
end

module Owner : sig
  val on_cleanup : (unit -> unit) -> unit
  val get_owner : unit -> Reactive_core.owner option
  val create_root : (unit -> 'a) -> (unit -> unit)
end

module Memo : sig
  type 'a t
  val create : ?equals:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t
  val get : 'a t -> 'a
  val peek : 'a t -> 'a
end

module Batch : sig
  val run : (unit -> 'a) -> 'a
end

module Context : sig
  type 'a t
  val create : 'a -> 'a t
  val provide : 'a t -> 'a -> (unit -> 'b) -> 'b
  val use : 'a t -> 'a
end

(** {1 Hydration Support} *)

val reset_hydration_keys : unit -> unit
(** Reset the hydration key counter. Called at the start of render/hydrate
    to ensure client-side key generation matches server-side. *)

(** {1 Reactive Text} *)

val text : int Signal.t -> Html.node
(** [text signal] creates a text node that updates when the signal changes.
    The signal value is converted to string via [string_of_int]. *)

val text_of : ('a -> string) -> 'a Signal.t -> Html.node
(** [text_of fmt signal] creates a text node with custom formatting. *)

val text_string : string Signal.t -> Html.node
(** [text_string signal] creates a text node from a string signal. *)

val memo_text : int Memo.t -> Html.node
(** [memo_text memo] creates a text node from an int memo. *)

val memo_text_of : ('a -> string) -> 'a Memo.t -> Html.node
(** [memo_text_of fmt memo] creates a text node from a memo with custom formatting. *)

(** {1 Attribute Bindings} *)

val bind_attr : Dom.element -> string -> string Signal.t -> unit
(** [bind_attr el attr_name signal] binds a signal to an attribute. *)

val bind_attr_opt : Dom.element -> string -> string option Signal.t -> unit
(** [bind_attr_opt el attr_name signal] binds an optional signal.
    When None, the attribute is removed. *)

val bind_class : Dom.element -> string Signal.t -> unit
(** [bind_class el signal] binds a signal to the class attribute. *)

val bind_style : Dom.element -> string -> string Signal.t -> unit
(** [bind_style el property signal] binds a signal to a CSS property. *)

(** {1 Visibility} *)

val bind_show : Dom.element -> bool Signal.t -> unit
(** [bind_show el signal] shows/hides using display:none. *)

val bind_class_toggle : Dom.element -> string -> bool Signal.t -> unit
(** [bind_class_toggle el class_name signal] adds/removes a class. *)

(** {1 Form Bindings} *)

val bind_input : Dom.element -> string Signal.t -> (string -> unit) -> unit
(** [bind_input el signal setter] creates two-way binding for text input. *)

val bind_checkbox : Dom.element -> bool Signal.t -> (bool -> unit) -> unit
(** [bind_checkbox el signal setter] creates two-way binding for checkbox. *)

(** {1 List Rendering} *)

val each : items:'a list Signal.t -> render:('a -> Html.node) -> Dom.element -> unit
(** [each ~items ~render parent] renders a reactive list.
    Re-renders all items when the list changes. *)

val each_keyed : items:'a list Signal.t -> key:('a -> string) -> 
  render:('a -> Html.node) -> Dom.element -> unit
(** [each_keyed ~items ~key ~render parent] renders a keyed list.
    Reuses DOM nodes for items with matching keys. *)

(** {1 Conditional Rendering} *)

val show : when_:bool Signal.t -> render:(unit -> Html.node) -> Dom.element -> unit
(** [show ~when_ ~render parent] conditionally renders content. *)

val if_ : when_:bool Signal.t -> then_:(unit -> Html.node) -> 
  else_:(unit -> Html.node) -> Dom.element -> unit
(** [if_ ~when_ ~then_ ~else_ parent] renders one of two alternatives. *)

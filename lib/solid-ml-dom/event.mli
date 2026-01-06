(** Event handling utilities.
    
    For simple cases, use the ?onclick etc. parameters on Html elements.
    This module provides additional utilities for advanced event handling.
*)

(** {1 Event Attachment}
    
    These functions attach event handlers and return a cleanup function. *)

val on_click : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_dblclick : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_mousedown : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_mouseup : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_mouseover : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_mouseout : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_mousemove : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_keydown : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_keyup : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_input : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_change : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_submit : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_focus : Dom.element -> (Dom.event -> unit) -> (unit -> unit)
val on_blur : Dom.element -> (Dom.event -> unit) -> (unit -> unit)

(** {1 Event Modifiers} *)

val prevent_default : (Dom.event -> unit) -> Dom.event -> unit
(** Wrap handler to call preventDefault *)

val stop_propagation : (Dom.event -> unit) -> Dom.event -> unit
(** Wrap handler to call stopPropagation *)

val prevent_and_stop : (Dom.event -> unit) -> Dom.event -> unit
(** Wrap handler to call both *)

(** {1 Mouse Events} *)

module Mouse : sig
  val client_x : Dom.event -> int
  val client_y : Dom.event -> int
  val button : Dom.event -> int
  val position : Dom.event -> int * int
  val is_left_button : Dom.event -> bool
  val is_middle_button : Dom.event -> bool
  val is_right_button : Dom.event -> bool
end

(** {1 Keyboard Events} *)

module Keyboard : sig
  val key : Dom.event -> string
  val code : Dom.event -> string
  val ctrl_key : Dom.event -> bool
  val shift_key : Dom.event -> bool
  val alt_key : Dom.event -> bool
  val meta_key : Dom.event -> bool
  val is_key : string -> Dom.event -> bool
  val is_enter : Dom.event -> bool
  val is_escape : Dom.event -> bool
  val is_space : Dom.event -> bool
  val is_tab : Dom.event -> bool
  val is_backspace : Dom.event -> bool
  val is_delete : Dom.event -> bool
  val is_arrow_up : Dom.event -> bool
  val is_arrow_down : Dom.event -> bool
  val is_arrow_left : Dom.event -> bool
  val is_arrow_right : Dom.event -> bool
  val has_modifier : Dom.event -> bool
end

(** {1 Input Events} *)

module Input : sig
  val value : Dom.event -> string
  val checked : Dom.event -> bool
end

(** {1 Event Delegation} *)

val delegate : Dom.element -> string -> (Dom.event -> Dom.element -> unit) -> (unit -> unit)
(** [delegate parent event_type handler] attaches a delegated handler *)

val delegate_matches : Dom.element -> string -> string -> (Dom.event -> Dom.element -> unit) -> (unit -> unit)
(** [delegate_matches parent event_type selector handler] only fires if target matches selector *)

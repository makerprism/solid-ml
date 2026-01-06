(** Event handling utilities.
    
    Provides convenient wrappers for DOM events.
    
    Note: For simple cases, use the ?onclick, ?oninput etc. parameters
    on Html element functions directly. This module is for more advanced
    event handling needs.
*)

open Dom

(** {1 Event Attachment} *)

(** Attach a click handler to an element. Returns a cleanup function. *)
let on_click element handler =
  add_event_listener element "click" handler;
  fun () -> remove_event_listener element "click" handler

let on_dblclick element handler =
  add_event_listener element "dblclick" handler;
  fun () -> remove_event_listener element "dblclick" handler

let on_mousedown element handler =
  add_event_listener element "mousedown" handler;
  fun () -> remove_event_listener element "mousedown" handler

let on_mouseup element handler =
  add_event_listener element "mouseup" handler;
  fun () -> remove_event_listener element "mouseup" handler

let on_mouseover element handler =
  add_event_listener element "mouseover" handler;
  fun () -> remove_event_listener element "mouseover" handler

let on_mouseout element handler =
  add_event_listener element "mouseout" handler;
  fun () -> remove_event_listener element "mouseout" handler

let on_mousemove element handler =
  add_event_listener element "mousemove" handler;
  fun () -> remove_event_listener element "mousemove" handler

let on_keydown element handler =
  add_event_listener element "keydown" handler;
  fun () -> remove_event_listener element "keydown" handler

let on_keyup element handler =
  add_event_listener element "keyup" handler;
  fun () -> remove_event_listener element "keyup" handler

let on_input element handler =
  add_event_listener element "input" handler;
  fun () -> remove_event_listener element "input" handler

let on_change element handler =
  add_event_listener element "change" handler;
  fun () -> remove_event_listener element "change" handler

let on_submit element handler =
  add_event_listener element "submit" handler;
  fun () -> remove_event_listener element "submit" handler

let on_focus element handler =
  add_event_listener element "focus" handler;
  fun () -> remove_event_listener element "focus" handler

let on_blur element handler =
  add_event_listener element "blur" handler;
  fun () -> remove_event_listener element "blur" handler

(** {1 Event Modifiers} *)

(** Wrap a handler to prevent default action *)
let prevent_default handler evt =
  Dom.prevent_default evt;
  handler evt

(** Wrap a handler to stop propagation *)
let stop_propagation handler evt =
  Dom.stop_propagation evt;
  handler evt

(** Wrap a handler to both prevent default and stop propagation *)
let prevent_and_stop handler evt =
  Dom.prevent_default evt;
  Dom.stop_propagation evt;
  handler evt

(** {1 Mouse Event Helpers} *)

module Mouse = struct
  let client_x = mouse_client_x
  let client_y = mouse_client_y
  let button = mouse_button
  
  let position evt =
    (mouse_client_x evt, mouse_client_y evt)
  
  let is_left_button evt = mouse_button evt = 0
  let is_middle_button evt = mouse_button evt = 1
  let is_right_button evt = mouse_button evt = 2
end

(** {1 Keyboard Event Helpers} *)

module Keyboard = struct
  let key = keyboard_key
  let code = keyboard_code
  let ctrl_key = keyboard_ctrl_key
  let shift_key = keyboard_shift_key
  let alt_key = keyboard_alt_key
  let meta_key = keyboard_meta_key
  
  let is_key k evt = keyboard_key evt = k
  let is_enter evt = keyboard_key evt = "Enter"
  let is_escape evt = keyboard_key evt = "Escape"
  let is_space evt = keyboard_key evt = " "
  let is_tab evt = keyboard_key evt = "Tab"
  let is_backspace evt = keyboard_key evt = "Backspace"
  let is_delete evt = keyboard_key evt = "Delete"
  let is_arrow_up evt = keyboard_key evt = "ArrowUp"
  let is_arrow_down evt = keyboard_key evt = "ArrowDown"
  let is_arrow_left evt = keyboard_key evt = "ArrowLeft"
  let is_arrow_right evt = keyboard_key evt = "ArrowRight"
  
  (** Check if any modifier key is pressed *)
  let has_modifier evt =
    keyboard_ctrl_key evt || keyboard_shift_key evt || 
    keyboard_alt_key evt || keyboard_meta_key evt
end

(** {1 Input Event Helpers} *)

module Input = struct
  let value = input_value
  let checked = input_checked
end

(** {1 Event Delegation} *)

(** Attach a delegated event handler.
    The handler receives the event and the target element.
    Use element.matches(selector) to filter events. *)
let delegate parent event_type handler =
  let delegated_handler evt =
    let target = element_of_event_target (event_target evt) in
    handler evt target
  in
  add_event_listener parent event_type delegated_handler;
  fun () -> remove_event_listener parent event_type delegated_handler

(** Delegated handler that only fires if target matches selector *)
let delegate_matches parent event_type selector handler =
  let delegated_handler evt =
    let target = element_of_event_target (event_target evt) in
    if matches target selector then
      handler evt target
  in
  add_event_listener parent event_type delegated_handler;
  fun () -> remove_event_listener parent event_type delegated_handler

(** Low-level DOM API bindings for Melange.
    
    These bindings provide direct access to browser DOM APIs.
*)

(** {1 Types} *)

type node
(** Abstract DOM node *)

type element
(** DOM Element *)

type text_node
(** DOM Text node *)

type comment_node
(** DOM Comment node *)

type document
(** DOM Document *)

type document_fragment
(** DOM DocumentFragment *)

type event
(** DOM Event *)

type event_target
(** Event target *)

type style
(** CSSStyleDeclaration *)

type class_list
(** DOMTokenList for classes *)

(** {1 Type Conversions} *)

val node_of_element : element -> node
val node_of_text : text_node -> node
val node_of_comment : comment_node -> node
val node_of_fragment : document_fragment -> node
val element_of_node : node -> element
val text_of_node : node -> text_node
val comment_of_node : node -> comment_node
val element_of_event_target : event_target -> element

(** {1 Global Objects} *)

val document : document
(** The global document object *)

(** {1 Document Methods} *)

val create_element : document -> string -> element
val create_element_ns : document -> string -> string -> element
val create_text_node : document -> string -> text_node
val create_comment : document -> string -> comment_node
val create_document_fragment : document -> document_fragment
val get_element_by_id : document -> string -> element option
val query_selector : document -> string -> element option
val query_selector_all : document -> string -> element list

(** {1 Node Methods} *)

val node_parent_node : node -> node option
val node_first_child : node -> node option
val node_next_sibling : node -> node option
val node_child_nodes : node -> node array
val node_type : node -> int
val node_text_content : node -> string option
val node_set_text_content : node -> string -> unit

(** {1 Element Methods} *)

val append_child : element -> node -> unit
val remove_child : element -> node -> unit
val insert_before : element -> node -> node option -> unit
(** Insert a node before a reference node. If reference is None, appends to end. *)
val replace_child : element -> node -> node -> unit
val clone_node : element -> bool -> element
(** Clone a DOM element. If deep is true, clone all descendants. *)

val get_id : element -> string
(** Get the id attribute of an element *)

val set_id : element -> string -> unit
(** Set the id attribute of an element *)
val set_attribute : element -> string -> string -> unit
val get_attribute : element -> string -> string option
val remove_attribute : element -> string -> unit
val has_attribute : element -> string -> bool
val set_inner_html : element -> string -> unit
val get_inner_html : element -> string
val get_tag_name : element -> string
val get_parent_element : element -> element option
val get_first_child : element -> node option
val get_next_sibling : element -> node option
val get_children : element -> element array
val get_child_nodes : element -> node array
val matches : element -> string -> bool

(** {1 DocumentFragment Methods} *)

val fragment_append_child : document_fragment -> node -> unit
val fragment_child_nodes : document_fragment -> node array

(** {1 Text Node Methods} *)

val text_data : text_node -> string
val text_set_data : text_node -> string -> unit
val text_parent_node : text_node -> node option

(** {1 Comment Node Methods} *)

val comment_data : comment_node -> string
val comment_set_data : comment_node -> string -> unit

(** {1 Node Type Checking} *)

val is_element : node -> bool
val is_text : node -> bool
val is_comment : node -> bool
val is_document_fragment : node -> bool

(** {1 Style Manipulation} *)

val get_style : element -> style
val style_set_property : style -> string -> string -> unit
val style_remove_property : style -> string -> unit
val set_style : element -> string -> string -> unit
val remove_style : element -> string -> unit

(** {1 Class Manipulation} *)

val get_class_list : element -> class_list
val class_list_add : class_list -> string -> unit
val class_list_remove : class_list -> string -> unit
val class_list_toggle : class_list -> string -> bool
val class_list_contains : class_list -> string -> bool
val add_class : element -> string -> unit
val remove_class : element -> string -> unit
val toggle_class : element -> string -> bool
val has_class : element -> string -> bool

val get_class_name : element -> string
(** Get the className of an element *)

val set_class_name : element -> string -> unit
(** Set the className of an element *)

(** {1 Event Handling} *)

val add_event_listener : element -> string -> (event -> unit) -> unit
val remove_event_listener : element -> string -> (event -> unit) -> unit
val event_target : event -> event_target
val event_current_target : event -> event_target
val target_opt : event -> element option
(** Get the target element of an event, if it is an element.
    Returns None if the target is not an element (e.g., window, document). *)

val target : event -> element
(** Get the target element of an event. Use only when you know the target is an element
    (e.g., click handlers on elements). For safer code, use target_opt. *)
val prevent_default : event -> unit
val stop_propagation : event -> unit
val event_type : event -> string

(** {1 Mouse Events} *)

val mouse_client_x : event -> int
val mouse_client_y : event -> int
val mouse_button : event -> int

(** {1 Keyboard Events} *)

val keyboard_key : event -> string
val keyboard_code : event -> string
val keyboard_ctrl_key : event -> bool
val keyboard_shift_key : event -> bool
val keyboard_alt_key : event -> bool
val keyboard_meta_key : event -> bool

(** {1 Input/Form} *)

val element_value : element -> string
val element_set_value : element -> string -> unit
val element_checked : element -> bool
val element_set_checked : element -> bool -> unit
val input_value : event -> string
val input_checked : event -> bool

(** {1 Focus} *)

val focus : element -> unit
val blur : element -> unit

(** {1 Timers} *)

val set_timeout : (unit -> unit) -> int -> int
val clear_timeout : int -> unit
val set_interval : (unit -> unit) -> int -> int
val clear_interval : int -> unit
val request_animation_frame : (float -> unit) -> int
val cancel_animation_frame : int -> unit

(** {1 Console} *)

val log : 'a -> unit
val error : 'a -> unit
val warn : 'a -> unit

(** {1 Exception Handling} *)

val exn_to_string : exn -> string
(** Get error message from an exception.
    This is a lightweight alternative to Printexc.to_string that avoids
    pulling in the heavy Printf/Format stdlib modules. *)

(** {1 History API} *)

val get_pathname : unit -> string
(** Get the current URL pathname *)

val get_search : unit -> string
(** Get the current URL search string (including ?) *)

val get_hash : unit -> string
(** Get the current URL hash (including #) *)

val get_href : unit -> string
(** Get the full current URL *)

val push_state : string -> unit
(** Push a new entry to the history stack *)

val replace_state : string -> unit
(** Replace the current history entry *)

val history_back : unit -> unit
(** Go back one entry in history *)

val history_forward : unit -> unit
(** Go forward one entry in history *)

val history_go : int -> unit
(** Go to a specific point in history *)

val on_popstate : (event -> unit) -> unit
(** Add a popstate event listener *)

val off_popstate : (event -> unit) -> unit
(** Remove a popstate event listener *)

(** {1 Scroll} *)

val get_scroll_x : unit -> float
(** Get current horizontal scroll position *)

val get_scroll_y : unit -> float
(** Get current vertical scroll position *)

val scroll_to : float -> float -> unit
(** Scroll to a position *)

val scroll_to_top : unit -> unit
(** Scroll to top of page *)

(** {1 Hydration} *)

val get_hydration_data : unit -> Js.Json.t Js.Nullable.t

(** {1 Helpers} *)

val remove_node : node -> unit
(** Remove a node from its parent *)

val remove_text_node : text_node -> unit
(** Remove a text node from its parent *)

val remove_element : element -> unit
(** Remove an element from its parent *)

val get_inner_text : element -> string
(** Get inner text of an element *)

val get_text_content : element -> string
(** Get text content of an element *)

val set_text_content : element -> string -> unit
(** Set text content of an element (faster than creating text nodes) *)

val get_data_attribute : element -> string -> string option
(** Get a data attribute value *)

val query_selector_within : element -> string -> element option
(** Query selector within an element *)

val query_selector_all_within : element -> string -> element list
(** Query selector all within an element *)

val set_location : string -> unit
(** Navigate to a URL (full page load) *)

(** {1 JavaScript Map} *)

(** JavaScript Map type - uses reference equality for object keys.
    This is needed for DOM reconciliation algorithms that use DOM elements as keys. *)
type ('k, 'v) js_map

val js_map_create : unit -> ('k, 'v) js_map
(** Create a new empty Map *)

val js_map_set : ('k, 'v) js_map -> 'k -> 'v -> ('k, 'v) js_map
(** Set a key-value pair, returns the map *)

val js_map_set_ : ('k, 'v) js_map -> 'k -> 'v -> unit
(** Set a key-value pair, ignoring return value *)

val js_map_get : ('k, 'v) js_map -> 'k -> 'v Js.undefined
(** Get a value by key, returns undefined if not found *)

val js_map_get_opt : ('k, 'v) js_map -> 'k -> 'v option
(** Get a value by key as option *)

val js_map_has : ('k, 'v) js_map -> 'k -> bool
(** Check if key exists *)

val js_map_delete : ('k, 'v) js_map -> 'k -> bool
(** Delete a key, returns true if key existed *)

val js_map_clear : ('k, 'v) js_map -> unit
(** Remove all entries *)

val js_map_size : ('k, 'v) js_map -> int
(** Get number of entries *)

(** {1 Promises} *)

(** JavaScript Promise type *)
type 'a promise

val promise_resolve : 'a -> 'a promise
(** Create a resolved promise *)

val promise_reject : exn -> 'a promise
(** Create a rejected promise *)

val promise_then : 'a promise -> ('a -> 'b) -> 'b promise
(** Chain a promise with a callback (then) *)

val promise_then_promise : 'a promise -> ('a -> 'b promise) -> 'b promise
(** Chain a promise with a promise-returning callback *)

val promise_catch : 'a promise -> (exn -> 'a) -> 'a promise
(** Catch promise rejection *)

val promise_finally : 'a promise -> (unit -> unit) -> 'a promise
(** Finally - runs regardless of success/failure *)

val promise_make : (('a -> unit) -> (exn -> unit) -> unit) -> 'a promise
(** Create a promise with resolve/reject callbacks *)

val promise_on_complete : 'a promise -> on_success:('a -> unit) -> on_error:(exn -> unit) -> unit
(** Run a promise and handle both success and error *)

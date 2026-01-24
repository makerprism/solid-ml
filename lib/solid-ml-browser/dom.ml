(** Low-level DOM API bindings for Melange.
    
    These bindings provide direct access to browser DOM APIs using Melange's
    FFI mechanism. The [@mel.*] attributes tell Melange how to translate
    OCaml calls to JavaScript.
*)

(** {1 DOM Node Types} *)

type node
type element
type text_node
type comment_node
type document
type document_fragment
type event
type event_target

(** {1 Type Conversions} *)

external node_of_element : element -> node = "%identity"
external node_of_text : text_node -> node = "%identity"
external node_of_comment : comment_node -> node = "%identity"
external node_of_fragment : document_fragment -> node = "%identity"
external element_of_node : node -> element = "%identity"
external text_of_node : node -> text_node = "%identity"
external comment_of_node : node -> comment_node = "%identity"
external element_of_event_target : event_target -> element = "%identity"

(** {1 Global Objects} *)

(** Get the document object. This is lazy to avoid errors in non-browser environments
    like Node.js when only using Promise/Timer APIs. *)
let document () : document = [%mel.raw "document"]

(** {1 Document Methods} *)

external create_element : document -> string -> element = "createElement"
  [@@mel.send]

external create_element_ns : document -> string -> string -> element = "createElementNS"
  [@@mel.send]

external create_text_node : document -> string -> text_node = "createTextNode"
  [@@mel.send]

external create_comment : document -> string -> comment_node = "createComment"
  [@@mel.send]

external create_document_fragment : document -> document_fragment = "createDocumentFragment"
  [@@mel.send]

external get_element_by_id : document -> string -> element option = "getElementById"
  [@@mel.send] [@@mel.return nullable]

external query_selector : document -> string -> element option = "querySelector"
  [@@mel.send] [@@mel.return nullable]

external query_selector_all : document -> string -> element array = "querySelectorAll"
  [@@mel.send]

(** {1 Node Methods} *)

external node_parent_node : node -> node option = "parentNode"
  [@@mel.get] [@@mel.return nullable]

external node_first_child : node -> node option = "firstChild"
  [@@mel.get] [@@mel.return nullable]

external node_next_sibling : node -> node option = "nextSibling"
  [@@mel.get] [@@mel.return nullable]

external node_child_nodes : node -> node array = "childNodes"
  [@@mel.get]

external node_type : node -> int = "nodeType"
  [@@mel.get]

external node_text_content : node -> string option = "textContent"
  [@@mel.get] [@@mel.return nullable]

external node_set_text_content : node -> string -> unit = "textContent"
  [@@mel.set]

(** {1 Element Methods} *)

external append_child : element -> node -> unit = "appendChild"
  [@@mel.send]

external remove_child : element -> node -> unit = "removeChild"
  [@@mel.send]

external insert_before_raw : element -> node -> node Js.nullable -> unit = "insertBefore"
  [@@mel.send]

let insert_before parent new_node ref_node =
  insert_before_raw parent new_node (Js.Nullable.fromOption ref_node)

external replace_child : element -> node -> node -> unit = "replaceChild"
  [@@mel.send]

external clone_node_raw : element -> bool -> node = "cloneNode"
  [@@mel.send]

let clone_node el deep = element_of_node (clone_node_raw el deep)

external set_attribute : element -> string -> string -> unit = "setAttribute"
  [@@mel.send]

external get_attribute : element -> string -> string option = "getAttribute"
  [@@mel.send] [@@mel.return nullable]

external get_id : element -> string = "id"
  [@@mel.get]

external set_id : element -> string -> unit = "id"
  [@@mel.set]

external remove_attribute : element -> string -> unit = "removeAttribute"
  [@@mel.send]

external has_attribute : element -> string -> bool = "hasAttribute"
  [@@mel.send]

external set_inner_html : element -> string -> unit = "innerHTML"
  [@@mel.set]

external get_inner_html : element -> string = "innerHTML"
  [@@mel.get]

external get_tag_name : element -> string = "tagName"
  [@@mel.get]

external get_parent_element : element -> element option = "parentElement"
  [@@mel.get] [@@mel.return nullable]

external get_first_child : element -> node option = "firstChild"
  [@@mel.get] [@@mel.return nullable]

external get_next_sibling : element -> node option = "nextSibling"
  [@@mel.get] [@@mel.return nullable]

external get_children : element -> element array = "children"
  [@@mel.get]

external get_child_nodes : element -> node array = "childNodes"
  [@@mel.get]

external matches : element -> string -> bool = "matches"
  [@@mel.send]

(** {1 DocumentFragment Methods} *)

external fragment_append_child : document_fragment -> node -> unit = "appendChild"
  [@@mel.send]

external fragment_child_nodes : document_fragment -> node array = "childNodes"
  [@@mel.get]

(** {1 Text Node Methods} *)

external text_data : text_node -> string = "data"
  [@@mel.get]

external text_set_data : text_node -> string -> unit = "data"
  [@@mel.set]

external text_parent_node : text_node -> node option = "parentNode"
  [@@mel.get] [@@mel.return nullable]

(** {1 Comment Node Methods} *)

external comment_data : comment_node -> string = "data"
  [@@mel.get]

external comment_set_data : comment_node -> string -> unit = "data"
  [@@mel.set]

(** {1 Node Type Checking} *)

let is_element node = node_type node = 1
let is_text node = node_type node = 3
let is_comment node = node_type node = 8
let is_document_fragment node = node_type node = 11

(** {1 Style Manipulation} *)

type style

external get_style : element -> style = "style"
  [@@mel.get]

external style_set_property : style -> string -> string -> unit = "setProperty"
  [@@mel.send]

external style_remove_property : style -> string -> unit = "removeProperty"
  [@@mel.send]

let set_style element property value =
  style_set_property (get_style element) property value

let remove_style element property =
  style_remove_property (get_style element) property

(** {1 Class Manipulation} *)

type class_list

external get_class_list : element -> class_list = "classList"
  [@@mel.get]

external class_list_add : class_list -> string -> unit = "add"
  [@@mel.send]

external class_list_remove : class_list -> string -> unit = "remove"
  [@@mel.send]

external class_list_toggle : class_list -> string -> bool = "toggle"
  [@@mel.send]

external class_list_contains : class_list -> string -> bool = "contains"
  [@@mel.send]

let add_class element cls =
  class_list_add (get_class_list element) cls

let remove_class element cls =
  class_list_remove (get_class_list element) cls

let toggle_class element cls =
  class_list_toggle (get_class_list element) cls

let has_class element cls =
  class_list_contains (get_class_list element) cls

external get_class_name : element -> string = "className"
  [@@mel.get]

external set_class_name : element -> string -> unit = "className"
  [@@mel.set]

(** {1 Event Handling} *)

external add_event_listener : element -> string -> (event -> unit) -> unit = "addEventListener"
  [@@mel.send]

external remove_event_listener : element -> string -> (event -> unit) -> unit = "removeEventListener"
  [@@mel.send]

external event_target : event -> event_target = "target"
  [@@mel.get]

external event_current_target : event -> event_target = "currentTarget"
  [@@mel.get]

(** Get target as element. Returns None if target is not an element (e.g., window, document).
    For input events where the target is known to be an element, this is safe to use with Option.get. *)
let target_opt evt =
  let t = event_target evt in
  (* In practice we check by seeing if it has tagName property *)
  let has_tag : event_target -> bool = [%mel.raw {| function(t) { return t && typeof t.tagName === 'string' } |}] in
  if has_tag t then Some (element_of_event_target t) else None

(** Get target as element, assuming it is one. Use only when you know the target is an element. *)
let target evt = element_of_event_target (event_target evt)

external prevent_default : event -> unit = "preventDefault"
  [@@mel.send]

external stop_propagation : event -> unit = "stopPropagation"
  [@@mel.send]

external event_type : event -> string = "type"
  [@@mel.get]

(** {1 Mouse Event Properties} *)

external mouse_client_x : event -> int = "clientX"
  [@@mel.get]

external mouse_client_y : event -> int = "clientY"
  [@@mel.get]

external mouse_button : event -> int = "button"
  [@@mel.get]

(** {1 Keyboard Event Properties} *)

external keyboard_key : event -> string = "key"
  [@@mel.get]

external keyboard_code : event -> string = "code"
  [@@mel.get]

external keyboard_ctrl_key : event -> bool = "ctrlKey"
  [@@mel.get]

external keyboard_shift_key : event -> bool = "shiftKey"
  [@@mel.get]

external keyboard_alt_key : event -> bool = "altKey"
  [@@mel.get]

external keyboard_meta_key : event -> bool = "metaKey"
  [@@mel.get]

(** {1 Input/Form Properties} *)

(* Get value from input element *)
external element_value : element -> string = "value"
  [@@mel.get]

external element_set_value : element -> string -> unit = "value"
  [@@mel.set]

external element_checked : element -> bool = "checked"
  [@@mel.get]

external element_set_checked : element -> bool -> unit = "checked"
  [@@mel.set]

(* Get target element's value from event *)
let input_value evt =
  let target = element_of_event_target (event_target evt) in
  element_value target

let input_checked evt =
  let target = element_of_event_target (event_target evt) in
  element_checked target

(** {1 Focus} *)

external focus : element -> unit = "focus"
  [@@mel.send]

external blur : element -> unit = "blur"
  [@@mel.send]

(** {1 Timers} *)

(** Note: These use globalThis which works in both browser and Node.js environments *)

external set_timeout : (unit -> unit) -> int -> int = "setTimeout"
  [@@mel.scope "globalThis"]

external clear_timeout : int -> unit = "clearTimeout"
  [@@mel.scope "globalThis"]

external set_interval : (unit -> unit) -> int -> int = "setInterval"
  [@@mel.scope "globalThis"]

external clear_interval : int -> unit = "clearInterval"
  [@@mel.scope "globalThis"]

external request_animation_frame : (float -> unit) -> int = "requestAnimationFrame"
  [@@mel.scope "globalThis"]

external cancel_animation_frame : int -> unit = "cancelAnimationFrame"
  [@@mel.scope "window"]

(** {1 Console} *)

external log : 'a -> unit = "log"
  [@@mel.scope "console"]

external error : 'a -> unit = "error"
  [@@mel.scope "console"]

external warn : 'a -> unit = "warn"
  [@@mel.scope "console"]

(** {1 Exception Handling} *)

(** Get error message from an exception.
    This is a lightweight alternative to Printexc.to_string that avoids
    pulling in the heavy Printf/Format stdlib modules. *)
let exn_to_string : exn -> string = [%mel.raw {|
  function(exn) {
    if (exn && exn.MEL_EXN_ID) {
      var msg = exn.MEL_EXN_ID;
      if (exn._1 !== undefined) msg += ": " + String(exn._1);
      return msg;
    } else if (exn instanceof Error) {
      return exn.message || exn.toString();
    } else {
      return String(exn);
    }
  }
|}]

(** {1 History API} *)

(** Get the current URL pathname *)
let get_pathname () : string =
  [%mel.raw {| window.location.pathname |}]

(** Get the current URL search string (including ?) *)
let get_search () : string =
  [%mel.raw {| window.location.search |}]

(** Get the current URL hash (including #) *)
let get_hash () : string =
  [%mel.raw {| window.location.hash |}]

(** Get the full current URL *)
let get_href () : string =
  [%mel.raw {| window.location.href |}]

(** Push a new entry to the history stack *)
let push_state url =
  let _ = url in
  [%mel.raw {| window.history.pushState(null, '', url) |}]

(** Replace the current history entry *)
let replace_state url =
  let _ = url in
  [%mel.raw {| window.history.replaceState(null, '', url) |}]

(** Go back one entry in history *)
let history_back () : unit =
  [%mel.raw {| window.history.back() |}]

(** Go forward one entry in history *)
let history_forward () : unit =
  [%mel.raw {| window.history.forward() |}]

(** Go to a specific point in history (negative = back, positive = forward) *)
let history_go delta =
  let _ = delta in
  [%mel.raw {| window.history.go(delta) |}]

(** Add a popstate event listener (for back/forward navigation) *)
let on_popstate handler =
  let _ = handler in
  [%mel.raw {| window.addEventListener('popstate', handler) |}]

(** Remove a popstate event listener *)
let off_popstate handler =
  let _ = handler in
  [%mel.raw {| window.removeEventListener('popstate', handler) |}]

(** Add an unload event listener (for page cleanup) *)
let on_unload handler =
  let _ = handler in
  [%mel.raw {| window.addEventListener('unload', handler) |}]

(** Remove an unload event listener *)
let off_unload handler =
  let _ = handler in
  [%mel.raw {| window.removeEventListener('unload', handler) |}]

(** {1 Scroll} *)

(** Get current scroll position *)
let get_scroll_x () : float =
  [%mel.raw {| window.scrollX || window.pageXOffset || 0 |}]

let get_scroll_y () : float =
  [%mel.raw {| window.scrollY || window.pageYOffset || 0 |}]

(** Scroll to a position *)
let scroll_to x y =
  let _ = (x, y) in
  [%mel.raw {| window.scrollTo(x, y) |}]

(** Scroll to top of page *)
let scroll_to_top () : unit =
  scroll_to 0.0 0.0

(** {1 JSON/Hydration Data} *)

let get_hydration_data () : Js.Json.t Js.Nullable.t =
  [%mel.raw {| window.__SOLID_ML_DATA__ || null |}]

(** {1 Helpers} *)

(** Remove a node from its parent *)
let remove_node node =
  match node_parent_node node with
  | Some parent_node ->
    let parent = element_of_node parent_node in
    remove_child parent node
  | None -> ()

(** Remove a text node from its parent *)
let remove_text_node txt =
  remove_node (node_of_text txt)

(** Remove an element from its parent *)
let remove_element el =
  remove_node (node_of_element el)

(** Get inner text of an element *)
external get_inner_text : element -> string = "innerText"
  [@@mel.get]

external get_text_content : element -> string = "textContent"
  [@@mel.get]

external set_text_content : element -> string -> unit = "textContent"
  [@@mel.set]

(** Get data attribute *)
let get_data_attribute el name =
  get_attribute el ("data-" ^ name)

(** Query selector within an element *)
external query_selector_within : element -> string -> element option = "querySelector"
  [@@mel.send] [@@mel.return nullable]

(** Query selector all within an element *)
external query_selector_all_within_raw : element -> string -> element array = "querySelectorAll"
  [@@mel.send]

let query_selector_all_within el selector =
  Array.to_list (query_selector_all_within_raw el selector)

(** Query selector all - returns list *)
let query_selector_all doc selector =
  Array.to_list (query_selector_all doc selector)

(** Set location (navigate) *)
let set_location path =
  let _ = path in
  [%mel.raw {| window.location.href = path |}]

(** {1 JavaScript Map} *)

(** JavaScript Map type - uses reference equality for object keys.
    This is needed for DOM reconciliation algorithms that use DOM elements as keys. *)
type ('k, 'v) js_map

external js_map_create : unit -> ('k, 'v) js_map = "Map" [@@mel.new]
external js_map_set : ('k, 'v) js_map -> 'k -> 'v -> ('k, 'v) js_map = "set" [@@mel.send]
external js_map_get : ('k, 'v) js_map -> 'k -> 'v Js.undefined = "get" [@@mel.send]
external js_map_has : ('k, 'v) js_map -> 'k -> bool = "has" [@@mel.send]
external js_map_delete : ('k, 'v) js_map -> 'k -> bool = "delete" [@@mel.send]
external js_map_clear : ('k, 'v) js_map -> unit = "clear" [@@mel.send]
external js_map_size : ('k, 'v) js_map -> int = "size" [@@mel.get]

let js_map_get_opt map key =
  Js.Undefined.toOption (js_map_get map key)

let js_map_set_ map key value =
  ignore (js_map_set map key value)

(** {1 Promises} *)

(** JavaScript Promise type *)
type 'a promise

(** Create a resolved promise *)
external promise_resolve : 'a -> 'a promise = "resolve"
  [@@mel.scope "Promise"]

(** Create a rejected promise *)
external promise_reject : exn -> 'a promise = "reject"
  [@@mel.scope "Promise"]

(** Chain a promise with a callback (then) *)
external promise_then : 'a promise -> ('a -> 'b) -> 'b promise = "then"
  [@@mel.send]

(** Chain a promise with a promise-returning callback *)
external promise_then_promise : 'a promise -> ('a -> 'b promise) -> 'b promise = "then"
  [@@mel.send]

(** Catch promise rejection *)
external promise_catch : 'a promise -> (exn -> 'a) -> 'a promise = "catch"
  [@@mel.send]

(** Finally - runs regardless of success/failure *)
external promise_finally : 'a promise -> (unit -> unit) -> 'a promise = "finally"
  [@@mel.send]

(** Create a promise with resolve/reject callbacks *)
let promise_make (executor : (('a -> unit) -> (exn -> unit) -> unit)) : 'a promise =
  let _ = executor in
  [%mel.raw {|
    new Promise(function(resolve, reject) {
      executor(resolve, reject);
    })
  |}]

(** Run a promise and handle both success and error *)
let promise_on_complete (p : 'a promise) ~(on_success : 'a -> unit) ~(on_error : exn -> unit) : unit =
  let _ = p in
  let _ = on_success in
  let _ = on_error in
  [%mel.raw {|
    p.then(on_success).catch(on_error)
  |}]

(* Re-export promise utilities to avoid unused warnings - these are public API *)
let _ = promise_resolve
let _ = promise_reject
let _ = promise_then
let _ = promise_then_promise
let _ = promise_catch
let _ = promise_finally
let _ = promise_make

(** Hydration state and utilities.
    
    Hydration is the process of "adopting" server-rendered DOM nodes and 
    attaching reactive bindings without re-creating elements.
    
    This module provides:
    - Hydration context creation and management
    - Functions to adopt existing elements and text nodes
    - Hydration marker parsing (<!--hk:N-->text<!--/hk-->)
    
    Note: In the browser, we use a simple global context since JavaScript
    is single-threaded. This is safe because only one hydration can occur
    at a time. The context is explicitly started/ended to catch misuse.
*)

open Dom

(** {1 Hydration State} *)

(** Hydration context tracks the current position in the DOM tree.
    Uses JS Map instead of OCaml Hashtbl to avoid pulling in heavy
    stdlib dependencies (Random, Domain, etc.) *)
type hydration_context = {
  mutable is_hydrating : bool;
  (** Map from hydration key to text node *)
  text_nodes : (int, text_node) js_map;
}

(** Create a fresh hydration context.
    Use this if you need isolated hydration (e.g., for testing). *)
let create_context () : hydration_context = {
  is_hydrating = false;
  text_nodes = js_map_create ();
}

(** The current hydration context.
    
    In the browser, we use a single global context since JS is single-threaded.
    The context is explicitly started/ended to prevent misuse. *)
let current_context : hydration_context ref = ref (create_context ())

(** Check if we're currently in hydration mode *)
let is_hydrating () = !current_context.is_hydrating

(** Start hydration mode.
    @raise Failure if already hydrating (indicates a bug) *)
let start_hydration () =
  if !current_context.is_hydrating then
    failwith "solid-ml: start_hydration called while already hydrating";
  !current_context.is_hydrating <- true;
  js_map_clear !current_context.text_nodes

(** End hydration mode.
    @raise Failure if not hydrating (indicates a bug) *)
let end_hydration () =
  if not !current_context.is_hydrating then
    failwith "solid-ml: end_hydration called while not hydrating";
  !current_context.is_hydrating <- false;
  js_map_clear !current_context.text_nodes

(** {1 Hydration Marker Parsing} *)

(** Parse hydration markers in server-rendered HTML.
    
    Server renders reactive text as:
      <!--hk:N-->content<!--/hk-->
    
    This function walks the DOM tree and extracts text nodes that follow
    opening markers, storing them in the context for later adoption. *)
let parse_hydration_markers root =
  let ctx = !current_context in
  js_map_clear ctx.text_nodes;
  
  let rec walk_children (parent : element) =
    let children = get_child_nodes parent in
    let len = Array.length children in
    let i = ref 0 in
    while !i < len do
      let node = children.(!i) in
      if is_comment node then begin
        let comment = comment_of_node node in
        let data = comment_data comment in
        (* Check for opening marker: hk:N *)
        if String.length data > 3 && String.sub data 0 3 = "hk:" then begin
          let key_str = String.sub data 3 (String.length data - 3) in
          match int_of_string_opt key_str with
          | Some key ->
            (* Next node should be the text content *)
            if !i + 1 < len then begin
              let next = children.(!i + 1) in
              if is_text next then begin
                let text_node = text_of_node next in
                js_map_set_ ctx.text_nodes key text_node
              end
            end
          | None -> ()
        end
      end else if is_element node then begin
        (* Recurse into child elements *)
        walk_children (element_of_node node)
      end;
      incr i
    done
  in
  
  walk_children root

(** {1 Node Adoption} *)

(** Get a text node for a hydration key, if one exists.
    Returns Some text_node if we're hydrating and have a node for this key. *)
let adopt_text_node key =
  let ctx = !current_context in
  if ctx.is_hydrating then
    js_map_get_opt ctx.text_nodes key
  else
    None

(** {1 Marker Cleanup} *)

(** Remove hydration markers from the DOM.
    Called after hydration is complete to clean up comments. *)
let remove_hydration_markers root =
  let markers_to_remove = ref [] in
  
  let rec walk_children (parent : element) =
    let children = get_child_nodes parent in
    Array.iter (fun node ->
      if is_comment node then begin
        let comment = comment_of_node node in
        let data = comment_data comment in
        (* Mark both opening (hk:N) and closing (/hk) markers for removal *)
        if (String.length data > 3 && String.sub data 0 3 = "hk:") 
           || data = "/hk" then
          markers_to_remove := node :: !markers_to_remove
      end else if is_element node then
        walk_children (element_of_node node)
    ) children
  in
  
  walk_children root;
  
  (* Remove all marked nodes *)
  List.iter remove_node !markers_to_remove

(** {1 Testing Support} *)

(** Reset the hydration context. 
    Only use this for testing to ensure clean state between tests. *)
let reset_for_testing () =
  current_context := create_context ()

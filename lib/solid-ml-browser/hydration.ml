(** Hydration state and utilities.
    
    Hydration is the process of "adopting" server-rendered DOM nodes and 
    attaching reactive bindings without re-creating elements.
    
    This module provides:
    - A global hydration context that tracks current DOM position
    - Functions to adopt existing elements and text nodes
    - Hydration marker parsing (<!--hk:N-->text<!--/hk-->)
*)

open Dom

(** {1 Hydration State} *)

(** Hydration context tracks the current position in the DOM tree. *)
type hydration_context = {
  mutable is_hydrating : bool;
  (** Map from hydration key to text node *)
  text_nodes : (int, text_node) Hashtbl.t;
}

(** Global hydration context *)
let context : hydration_context = {
  is_hydrating = false;
  text_nodes = Hashtbl.create 16;
}

(** Check if we're currently in hydration mode *)
let is_hydrating () = context.is_hydrating

(** Start hydration mode *)
let start_hydration () =
  context.is_hydrating <- true;
  Hashtbl.clear context.text_nodes

(** End hydration mode *)
let end_hydration () =
  context.is_hydrating <- false;
  Hashtbl.clear context.text_nodes

(** {1 Hydration Marker Parsing} *)

(** Parse hydration markers in server-rendered HTML.
    
    Server renders reactive text as:
      <!--hk:N-->content<!--/hk-->
    
    This function walks the DOM tree and extracts text nodes that follow
    opening markers, storing them in the context for later adoption. *)
let parse_hydration_markers root =
  Hashtbl.clear context.text_nodes;
  
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
                Hashtbl.add context.text_nodes key text_node
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
  if context.is_hydrating then
    Hashtbl.find_opt context.text_nodes key
  else
    None

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

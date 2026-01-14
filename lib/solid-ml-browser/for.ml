(** For component - keyed list rendering for browser.
    
    Renders a list of items with efficient updates via keyed reconciliation.
    Items are keyed by their identity (reference equality), making reordering
    efficient by moving DOM nodes rather than recreating them.
    
    Matches SolidJS <For> component API:
    - Keys by item identity (referential equality)
    - Returns plain item value (not a signal)
    - Index is a signal: (unit -> int)
    - Handles reordering efficiently
    
    Usage:
      For.create
        ~each:items
        ~fallback:(div [] [text "No items"])
        ~children:(fun item index ->
          div [] [text (item.name ^ " #" ^ string_of_int (index ()))]
        )
 *)

[@@@warning "-33-26"]

open Html
open Dom

module Signal = Reactive.Signal
module Effect = Reactive.Effect
module Owner = Reactive.Owner

(** {1 Types} *)

type 'a for_props = {
  each : 'a list Signal.t;
  fallback : Html.node option;
  children : ('a -> (unit -> int) -> Html.node);
}

(** {1 Internal State} *)

type 'a item_state = {
  item : 'a;
  node : Dom.node;
  mutable index : int;
}

(** {1 Helper Functions} *)

let key_of_item (type a) (item : a) : string =
  let obj = Obj.repr item in
  if Obj.is_int obj then
    "i:" ^ string_of_int (Obj.obj obj)
  else
    "o:" ^ string_of_int (Obj.magic obj : int)

(** {1 For Component} *)

let create (type a) (props : a for_props) : Html.node =
  let open Html in
  let open Dom in
  
  let items_ref : a item_state list ref = ref [] in
  let placeholder = create_comment (document ()) "for" in
  let placeholder_node = node_of_comment placeholder in
  let current_items_ref : a list ref = ref [] in
  
  Effect.create (fun () ->
    let new_items = Signal.get props.each in
    let old_items = !current_items_ref in
    
    if old_items == new_items then
      ()
    else
      begin
        current_items_ref := new_items;
        
        let key_to_state = js_map_create () in
        List.iter (fun state ->
          let key = key_of_item state.item in
          js_map_set_ key_to_state key state
        ) !items_ref;
        
        let parent = match node_parent_node placeholder_node with
          | Some parent -> element_of_node parent
          | None -> assert false
        in
        
        let new_states = ref [] in
        let processed_keys = js_map_create () in
        
        List.iteri (fun new_index new_item ->
          let key = key_of_item new_item in
          
          let state = match js_map_get_opt key_to_state key with
            | Some existing -> 
              existing.index <- new_index;
              js_map_set_ processed_keys key existing;
              existing
            | None ->
              let node = Html.to_dom_node (props.children new_item (fun () -> new_index)) in
              let state = { item = new_item; node; index = new_index } in
              js_map_set_ processed_keys key state;
              state
          in
          new_states := state :: !new_states
        ) new_items;
        
        List.iter (fun old_state ->
          let key = key_of_item old_state.item in
          if not (js_map_has processed_keys key) then
            begin
              remove_node old_state.node;
              items_ref := List.filter (fun s -> s != old_state) !items_ref
            end
        ) !items_ref;
        
        items_ref := List.rev !new_states;
        
        let item_nodes = List.map (fun s -> s.node) !items_ref in
        List.iter (fun node -> remove_node node) item_nodes;
        List.iter (fun node -> insert_before parent node (Some placeholder_node)) item_nodes
      end
  );
  
  Owner.on_cleanup (fun () ->
    List.iter (fun state -> Dom.remove_node state.node) !items_ref
  );
  
  match props.fallback with
  | Some fb ->
    let fallback_node = Html.to_dom_node fb in
    let fallback_placeholder = create_comment (document ()) "for-fallback" in
    
    Effect.create (fun () ->
      let items = Signal.get props.each in
      let parent = element_of_node (Option.get (node_parent_node placeholder_node)) in
      if items = [] then
        insert_before parent fallback_node (Some placeholder_node)
      else
        Dom.remove_node fallback_node
    );
    
    Owner.on_cleanup (fun () -> Dom.remove_node fallback_node);
    
    Text (create_text_node (document ()) "")
  | None ->
    Text (create_text_node (document ()) "")

(** {1 Shorthand} *)

let create' ?fallback ~(each : 'a list Signal.t) ~(children : ('a -> Html.node)) () : Html.node =
  create {
    each;
    fallback;
    children = (fun item _ -> children item);
  }

let create_indexed ?fallback ~(each : 'a list Signal.t) 
    ~(children : ('a -> int -> Html.node)) () : Html.node =
  create {
    each;
    fallback;
    children = (fun item index_signal -> children item (index_signal ()));
  }

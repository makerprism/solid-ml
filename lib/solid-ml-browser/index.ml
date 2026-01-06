(** Index component - position-keyed list rendering for browser.
    
    Renders a list of items keyed by their array position (index).
    Unlike For, the item is passed as a signal, so updates to the item
    value don't require re-evaluating the render function.
    
    Matches SolidJS <Index> component API:
    - Keys by array position (index)
    - Item is a signal: (unit -> a)
    - Index is a plain int (not a signal)
    - Efficient for stable-position content updates
    
    Usage:
      Index.create
        ~each:items
        ~fallback:(div [] [text "Loading..."])
        ~children:(fun item index ->
          input ~value:(item ()) ()
        )
    
    Best for:
    - Form inputs at stable positions
    - Large lists with frequent content updates
    - Primitive values (strings, numbers) at stable positions
 *)

open Html
open Dom

(** {1 Types} *)

type 'a index_props = {
  each : 'a list Signal.t;
  fallback : Html.node option;
  children : ((unit -> 'a) -> int -> Html.node);
}

(** {1 Internal State} *)

type 'a index_state = {
  node : Dom.node;
  item_signal : (unit -> 'a);
  mutable index : int;
}

(** {1 Index Component} *)

let create (type a) (props : a index_props) : Html.node =
  let open Html in
  let open Dom in
  
  let items_ref : a index_state list ref = ref [] in
  let placeholder = create_comment document "index" in
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
        
        let parent = match node_parent_node placeholder_node with
          | Some parent -> element_of_node parent
          | None -> assert false
        in
        
        let old_len = List.length !items_ref in
        let new_len = List.length new_items in
        
        List.iteri (fun i item ->
          if i < old_len then
            begin
              let state = List.nth !items_ref i in
              state.index <- i
            end
          else
            begin
              let item_signal () = List.nth new_items i in
              let node = Html.to_dom_node (props.children item_signal i) in
              insert_before parent node (Some placeholder_node);
              let new_state = { node; item_signal; index = i } in
              items_ref := List.append !items_ref [new_state]
            end
        ) new_items;
        
        if new_len < old_len then
          begin
            let to_remove = List.filter (fun s -> s.index >= new_len) !items_ref in
            items_ref := List.filter (fun s -> s.index < new_len) !items_ref;
            List.iter (fun s -> Dom.remove_node s.node) to_remove
          end
      end
  );
  
  Owner.on_cleanup (fun () ->
    List.iter (fun state -> Dom.remove_node state.node) !items_ref
  );
  
  match props.fallback with
  | Some fb ->
    let fallback_node = Html.to_dom_node fb in
    
    Effect.create (fun () ->
      let items = Signal.get props.each in
      let parent = element_of_node (Option.get (node_parent_node placeholder_node)) in
      if items = [] then
        insert_before parent fallback_node (Some placeholder_node)
      else
        Dom.remove_node fallback_node
    );
    
    Owner.on_cleanup (fun () -> Dom.remove_node fallback_node);
    
    Text (create_text_node document "")
  | None ->
    Text (create_text_node document "")

(** {1 Shorthand} *)

let create' ?fallback ~(each : 'a list Signal.t) 
    ~(children : ((unit -> 'a) -> Html.node)) () : Html.node =
  create {
    each;
    fallback;
    children = (fun item_signal _ -> children item_signal);
  }

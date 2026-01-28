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

[@@@warning "-33-27"]

open Html
open Dom

module Signal = Reactive.Signal
module Effect = Reactive.Effect
module Owner = Reactive.Owner

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
  index_ref : int ref;
}

(** {1 Index Component} *)

let create (type a) (props : a index_props) : Html.node =
  let open Html in
  let open Dom in
  
  let items_ref : a index_state list ref = ref [] in
  let placeholder = create_text_node (document ()) "" in
  let placeholder_node = node_of_text placeholder in
  let current_items_ref : a list ref = ref [] in
  let fallback_node_ref : Dom.node option ref = ref None in

  let initial_items = Signal.peek props.each in
  current_items_ref := initial_items;
  let initial_states, initial_nodes =
    List.mapi
      (fun i _item ->
        let index_ref = ref i in
        let item_signal () =
          let items = Signal.get props.each in
          List.nth items !index_ref
        in
        let html_node = props.children item_signal i in
        let node = Html.to_dom_node html_node in
        ({ node; item_signal; index_ref }, html_node))
      initial_items
    |> List.split
  in
  items_ref := initial_states;
  
  let update_items new_items =
    Reactive_core.with_mount_scope (fun () ->
    let old_items = !current_items_ref in
    if old_items == new_items then
      ()
    else
      begin
        current_items_ref := new_items;

        let parent = match node_parent_node placeholder_node with
          | Some parent -> element_of_node parent
          | None -> raise (Failure "solid-ml: Index placeholder not mounted")
        in

        (match !fallback_node_ref with
         | Some fb_node ->
            if new_items = [] then
              insert_before parent fb_node (Some placeholder_node)
            else
              Dom.remove_node fb_node
          | None -> ());

        let old_len = List.length !items_ref in
        let new_len = List.length new_items in

        List.iteri (fun i item ->
          if i < old_len then
            begin
              let state = List.nth !items_ref i in
              state.index_ref := i
            end
          else
            begin
              let item_signal () =
                let items = Signal.get props.each in
                List.nth items i
              in
              let node = Html.to_dom_node (props.children item_signal i) in
              insert_before parent node (Some placeholder_node);
              let new_state = { node; item_signal; index_ref = ref i } in
              items_ref := List.append !items_ref [new_state]
            end
        ) new_items;

        if new_len < old_len then
          begin
            let to_remove = List.filter (fun s -> !(s.index_ref) >= new_len) !items_ref in
            items_ref := List.filter (fun s -> !(s.index_ref) < new_len) !items_ref;
             List.iter (fun s -> Dom.remove_node s.node) to_remove
          end
      end
    )
  in

  Effect.create_deferred
    ~track:(fun () -> Signal.get props.each)
    ~run:update_items;
  
  Owner.on_cleanup (fun () ->
    List.iter (fun state -> Dom.remove_node state.node) !items_ref
  );
  
  match props.fallback with
  | Some fb ->
    let fallback_node = Html.to_dom_node fb in
    fallback_node_ref := Some fallback_node;
    let fallback_html =
      if is_element fallback_node then
        Html.Element (element_of_node fallback_node)
      else if is_text fallback_node then
        Html.Text (text_of_node fallback_node)
      else if is_document_fragment fallback_node then
        Html.Fragment (fragment_of_node fallback_node)
      else
        Html.Empty
    in
    let initial_render_nodes =
      if initial_items = [] then fallback_html :: initial_nodes else initial_nodes
    in

    Owner.on_cleanup (fun () -> Dom.remove_node fallback_node);

    Html.fragment (initial_render_nodes @ [Text placeholder])
  | None ->
    Html.fragment (initial_nodes @ [Text placeholder])

(** {1 Shorthand} *)

let create' ?fallback ~(each : 'a list Signal.t) 
    ~(children : ((unit -> 'a) -> Html.node)) () : Html.node =
  create {
    each;
    fallback;
    children = (fun item_signal _ -> children item_signal);
  }

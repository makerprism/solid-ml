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

let is_js_string : Obj.t -> bool =
  [%mel.raw {|
    function (x) { return typeof x === "string"; }
  |}]

let object_ids : (Obj.t, int) js_map = js_map_create ()
let next_object_id = ref 0

let get_object_id obj =
  match js_map_get_opt object_ids obj with
  | Some id -> id
  | None ->
    let id = !next_object_id in
    incr next_object_id;
    js_map_set_ object_ids obj id;
    id

let key_of_item (type a) (item : a) : string =
  let obj = Obj.repr item in
  if Obj.is_int obj then
    "i:" ^ string_of_int (Obj.obj obj)
  else if is_js_string obj then
    "s:" ^ (Obj.magic obj : string)
  else
    "o:" ^ string_of_int (get_object_id obj)

(** {1 For Component} *)

let create (type a) (props : a for_props) : Html.node =
  let open Html in
  let open Dom in
  
  let items_ref : a item_state list ref = ref [] in
  let placeholder = create_text_node (document ()) "" in
  let placeholder_node = node_of_text placeholder in
  let current_items_ref : a list ref = ref [] in

  let build_state index item =
    let html_node = props.children item (fun () -> index) in
    let node = Html.to_dom_node html_node in
    ({ item; node; index }, html_node)
  in

  let initial_items = Signal.peek props.each in
  let initial_states, initial_nodes =
    List.mapi build_state initial_items
    |> List.split
  in
  items_ref := initial_states;
  current_items_ref := initial_items;

  let update_items new_items =
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
          | None -> raise (Failure "solid-ml: For placeholder not mounted")
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
    let _fallback_placeholder = create_comment (document ()) "for-fallback" in

    Effect.create_deferred
      ~track:(fun () -> Signal.get props.each)
      ~run:(fun items ->
        let parent = match node_parent_node placeholder_node with
          | Some parent -> element_of_node parent
          | None -> raise (Failure "solid-ml: For fallback not mounted")
        in
        if items = [] then
          insert_before parent fallback_node (Some placeholder_node)
        else
          Dom.remove_node fallback_node);
    
    Owner.on_cleanup (fun () -> Dom.remove_node fallback_node);
    
    Html.fragment (initial_nodes @ [Text placeholder])
  | None ->
    Html.fragment (initial_nodes @ [Text placeholder])

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

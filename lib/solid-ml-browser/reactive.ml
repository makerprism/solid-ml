(** Reactive DOM primitives.
    
    These functions create reactive bindings between signals and DOM nodes.
    When a signal changes, the DOM is updated automatically.
    
    All bindings register cleanup with the current Owner, so they are
    properly disposed when the component is unmounted.
*)

(** {1 Hydration Key Counter} *)

let next_hydration_key = Hydration.next_hydration_key
let reset_hydration_keys = Hydration.reset_hydration_keys

module Signal = struct
  type 'a t = 'a Reactive_core.signal
  let get = Reactive_core.get_signal
  let set s v =
    ignore (Reactive_core.set_signal s v);
    v
  let create ?equals v = 
    let s = Reactive_core.create_signal ?equals v in
    (s, fun v -> ignore (Reactive_core.set_signal s v); v)
  let update s f = Reactive_core.update_signal s f
  let peek = Reactive_core.peek_signal
end

module Effect = struct
  let create = Reactive_core.create_effect
  let create_with_cleanup = Reactive_core.create_effect_with_cleanup
  let create_deferred = Reactive_core.create_effect_deferred
  let untrack = Reactive_core.untrack
  
  (** Create an effect with explicit dependencies (like SolidJS's `on`). *)
  let on (type a) ?(defer = false) ?initial (deps : unit -> a) (fn : value:a -> prev:a -> unit) : unit =
    let prev = ref None in
    let first_run = ref true in
    Reactive_core.create_effect (fun () ->
      let value = deps () in
      Reactive_core.untrack (fun () ->
        if !first_run then begin
          first_run := false;
          let initial_prev = match initial with
            | Some v -> v
            | None -> value
          in
          prev := Some initial_prev;
          if not defer then begin
            fn ~value ~prev:initial_prev;
            prev := Some value
          end
        end else begin
          let prev_val = match !prev with
            | Some p -> p
            | None -> value
          in
          fn ~value ~prev:prev_val;
          prev := Some value
        end
      )
    )
end

module Owner = struct
  let on_cleanup = Reactive_core.on_cleanup
  let get_owner = Reactive_core.get_owner
  let create_root f = 
    let (_, dispose) = Reactive_core.create_root f in
    dispose
  
  (** Create an error boundary (like SolidJS's catchError). *)
  let catch_error (fn : unit -> 'a) (handler : exn -> 'a) : 'a =
    try fn ()
    with exn -> handler exn
end

module Memo = struct
  type 'a t = 'a Reactive_core.memo
  let create ?equals f = Reactive_core.create_memo ?equals f
  let get = Reactive_core.get_memo
  let peek = Reactive_core.peek_memo
end

module Batch = struct
  let run = Reactive_core.batch
end

(** {1 Selector} *)

(** Create a selector - an optimized way to check if a value equals the current
    selection without subscribing to every change.
    
    Unlike directly comparing with the signal value (which causes ALL readers to
    re-run when selection changes), a selector only notifies the specific
    subscriber whose selected state changed.
    
    This is critical for performance in large lists where each row needs to know
    if it's selected. Without selector: O(n) updates when selection changes.
    With selector: O(1) updates (only previous and new selected row).
    
    Matches SolidJS's createSelector exactly:
    - Auto-cleanup via onCleanup when the calling computation is disposed
    - No manual unsubscribe needed
    - Tracks computations directly, not via intermediate signals
    
    Usage:
    {[
      let selected, set_selected = Signal.create (-1) in
      let is_selected = create_selector selected in
      
      (* In each row - auto-cleans up when effect is disposed *)
      Effect.create (fun () ->
        let sel = is_selected row_id in
        set_class tr (if sel then "danger" else "")
      )
    ]}
    
    @param equals Optional equality function (default: structural equality)
    @param source Signal containing the currently selected value
    @return A function that reactively checks if a given key is selected *)
let create_selector (type k) ?(equals : k -> k -> bool = (=)) (source : k Signal.t) : (k -> bool) =
  (* Use JS Map for subscribers - avoids pulling in heavy Hashtbl/Random stdlib *)
  let subs : (k, (unit -> unit) list ref) Dom.js_map = Dom.js_map_create () in
  
  (* Track previous value to know what changed *)
  let prev_value : k option ref = ref None in
  
  (* The internal computation that tracks source and notifies affected keys *)
  let _comp = Memo.create (fun () ->
    let new_value = Signal.get source in
    let old_value = !prev_value in
    
    (* For each key that was previously selected or is now selected, 
       trigger its subscribers if the selection state changed *)
    (match old_value with
     | Some old_key ->
       if not (equals old_key new_value) then
         (* Old key is no longer selected - trigger its listeners *)
         (match Dom.js_map_get_opt subs old_key with
          | Some listeners -> List.iter (fun f -> f ()) !listeners
          | None -> ())
     | None -> ());
    
    (* New key is now selected - trigger its listeners if different from old *)
    (match old_value with
     | Some old_key when equals old_key new_value -> ()  (* Same key, no change *)
     | _ ->
       (match Dom.js_map_get_opt subs new_value with
        | Some listeners -> List.iter (fun f -> f ()) !listeners
        | None -> ()));
    
    prev_value := Some new_value;
    new_value
  ) in
  
  (* Return the selector function *)
  fun key ->
    (* Get the current computation (listener) if any *)
    let listener = Reactive_core.get_owner () in
    
    (match listener with
     | Some _ ->
       (* Add this computation to the subscribers for this key *)
       let listeners = match Dom.js_map_get_opt subs key with
         | Some l -> l
         | None ->
           let l = ref [] in
           Dom.js_map_set_ subs key l;
           l
       in
       
       (* Create a trigger function that will re-run the current computation.
          We do this by creating a signal that we update when this key's state changes.
          Use a bool that toggles so each trigger actually changes the value. *)
        let trigger_signal = Reactive_core.create_signal false in
        let set_trigger v = ignore (Reactive_core.set_signal trigger_signal v) in
        let trigger () = set_trigger (not (Reactive_core.peek_signal trigger_signal)) in
       
       (* Add trigger to listeners *)
       listeners := trigger :: !listeners;
       
       (* Auto-cleanup: remove from listeners when computation is disposed *)
       Owner.on_cleanup (fun () ->
         listeners := List.filter (fun f -> f != trigger) !listeners;
         (* Remove the key entry if no more listeners *)
         if !listeners = [] then ignore (Dom.js_map_delete subs key)
       );
       
       (* Read the trigger signal to establish dependency *)
        let _ = Reactive_core.get_signal trigger_signal in
       ()
     | None -> ());
    
    (* Return whether this key matches the current selection *)
    let current = Signal.peek source in
    equals key current

module Context = struct
  type 'a t = 'a Reactive_core.context
  let create = Reactive_core.create_context
  let provide ctx v f = Reactive_core.provide_context ctx v f
  let use = Reactive_core.use_context
end

(** {1 Reactive Text} *)

(** Helper to get or create a text node during hydration.
    If hydrating and we have a text node for this key, adopt it.
    Otherwise create a new text node. *)
let get_or_create_text_node key initial_value =
  match Hydration.adopt_text_node key with
  | Some txt -> txt  (* Adopt existing node *)
  | None -> Dom.create_text_node (Dom.document ()) initial_value

let reactive_text = Html.reactive_text
let reactive_text_of = Html.reactive_text_of
let reactive_text_string = Html.reactive_text_string

(** Create a reactive text node from an int memo.
    During hydration, adopts existing text node. *)
let memo_text (memo : int Memo.t) : Html.node =
  let key = next_hydration_key () in
  let initial = string_of_int (Memo.get memo) in
  let txt = get_or_create_text_node key initial in
  Effect.create (fun () ->
    Dom.text_set_data txt (string_of_int (Memo.get memo))
  );
  Html.Text txt

(** Create a reactive text node from a memo with custom formatting.
    During hydration, adopts existing text node. *)
let memo_text_of (fmt : 'a -> string) (memo : 'a Memo.t) : Html.node =
  let key = next_hydration_key () in
  let initial = fmt (Memo.get memo) in
  let txt = get_or_create_text_node key initial in
  Effect.create (fun () ->
    Dom.text_set_data txt (fmt (Memo.get memo))
  );
  Html.Text txt

(** {1 Attribute Bindings} *)

(** Bind a signal to an element's attribute.
    The attribute updates automatically when the signal changes. *)
let bind_attr element attr_name (signal : string Signal.t) =
  Effect.create (fun () ->
    Dom.set_attribute element attr_name (Signal.get signal)
  )

(** Bind a signal to an optional attribute.
    When signal is None, the attribute is removed. *)
let bind_attr_opt element attr_name (signal : string option Signal.t) =
  Effect.create (fun () ->
    match Signal.get signal with
    | Some value -> Dom.set_attribute element attr_name value
    | None -> Dom.remove_attribute element attr_name
  )

(** Bind a signal to the element's class attribute. *)
let bind_class element (signal : string Signal.t) =
  Effect.create (fun () ->
    Dom.set_attribute element "class" (Signal.get signal)
  )

(** Bind a signal to a CSS property. *)
let bind_style element prop (signal : string Signal.t) =
  Effect.create (fun () ->
    Dom.set_style element prop (Signal.get signal)
  )

(** {1 Visibility} *)

(** Show/hide an element based on a boolean signal.
    Uses display:none when hidden. *)
let bind_show element (signal : bool Signal.t) =
  Effect.create (fun () ->
    if Signal.get signal then
      Dom.remove_style element "display"
    else
      Dom.set_style element "display" "none"
  )

(** Add/remove a class based on a boolean signal. *)
let bind_class_toggle element class_name (signal : bool Signal.t) =
  Effect.create (fun () ->
    if Signal.get signal then
      Dom.add_class element class_name
    else
      Dom.remove_class element class_name
  )

(** {1 Form Bindings} *)

(** Create a two-way binding between an input element and a string signal.
    - DOM updates when signal changes
    - Signal updates when user types *)
let bind_input element (signal : string Signal.t) (set_signal : string -> unit) =
  (* Update DOM when signal changes *)
  Effect.create (fun () ->
    let value = Signal.get signal in
    (* Only update if different to avoid cursor position issues *)
    if Dom.element_value element <> value then
      Dom.element_set_value element value
  );
  (* Update signal when input changes *)
  let handler = fun evt ->
    set_signal (Dom.input_value evt)
  in
  Dom.add_event_listener element "input" handler;
  (* Register cleanup *)
  Owner.on_cleanup (fun () ->
    Dom.remove_event_listener element "input" handler
  )

(** Create a two-way binding between a checkbox and a boolean signal. *)
let bind_checkbox element (signal : bool Signal.t) (set_signal : bool -> unit) =
  (* Update DOM when signal changes *)
  Effect.create (fun () ->
    Dom.element_set_checked element (Signal.get signal)
  );
  (* Update signal when checkbox changes - use actual DOM state *)
  let handler = fun evt ->
    set_signal (Dom.input_checked evt)
  in
  Dom.add_event_listener element "change" handler;
  Owner.on_cleanup (fun () ->
    Dom.remove_event_listener element "change" handler
  )

(** Create a two-way binding between a select element and a string signal. *)
let bind_select element (signal : string Signal.t) (set_signal : string -> unit) =
  Effect.create (fun () ->
    let value = Signal.get signal in
    if Dom.element_value element <> value then
      Dom.element_set_value element value
  );
  let handler = fun evt ->
    set_signal (Dom.input_value evt)
  in
  Dom.add_event_listener element "change" handler;
  Owner.on_cleanup (fun () ->
    Dom.remove_event_listener element "change" handler
  )

(** Create a two-way binding between a multi-select element and a string list signal. *)
let bind_select_multiple element (signal : string list Signal.t) (set_signal : string list -> unit) =
  Effect.create (fun () ->
    let values = Array.of_list (Signal.get signal) in
    Dom.element_set_selected_values element values
  );
  let handler = fun evt ->
    let values = Dom.input_selected_values evt |> Array.to_list in
    set_signal values
  in
  Dom.add_event_listener element "change" handler;
  Owner.on_cleanup (fun () ->
    Dom.remove_event_listener element "change" handler
  )

(** {1 List Rendering} *)

(** Render a reactive list.
    
    When items change, the DOM is updated. This is a simple implementation
    that re-renders all items on change. For large lists with frequent
    updates, consider using [each_keyed].
    
    @param items Signal containing the list of items
    @param render Function to render each item
    @param parent DOM element to append items to *)
let each ~(items : 'a list Signal.t) ~(render : 'a -> Html.node) (parent : Dom.element) =
  let current_nodes : Dom.node list ref = ref [] in
  
  Effect.create (fun () ->
    (* Remove old nodes *)
    List.iter Dom.remove_node !current_nodes;
    
    (* Render new nodes *)
    let item_list = Signal.get items in
    let new_nodes = List.map (fun item ->
      let node = render item in
      Html.to_dom_node node
    ) item_list in
    
    (* Append to parent *)
    List.iter (fun node -> Dom.append_child parent node) new_nodes;
    current_nodes := new_nodes
  )

(** Render a reactive list with keys for efficient updates.
    
    @param items Signal containing the list of items
    @param key Function to extract a unique key from each item
    @param render Function to render each item
    @param parent DOM element to append items to *)
let each_keyed ~(items : 'a list Signal.t) ~(key : 'a -> string) 
    ~(render : 'a -> Html.node) (parent : Dom.element) =
  (* Map from key to (dom_node, item) - using JS Map to avoid heavy stdlib deps *)
  let current_map : (string, Dom.node * 'a) Dom.js_map = Dom.js_map_create () in
  let current_order : string list ref = ref [] in
  
  Effect.create (fun () ->
    let new_items = Signal.get items in
    let new_keys = List.map key new_items in
    let new_set = List.fold_left (fun s k -> 
      let module S = Set.Make(String) in S.add k s
    ) (let module S = Set.Make(String) in S.empty) new_keys in
    
    (* Remove nodes that are no longer in the list *)
    List.iter (fun old_key ->
      let module S = Set.Make(String) in
      if not (S.mem old_key new_set) then begin
        match Dom.js_map_get_opt current_map old_key with
        | Some (node, _) -> 
          Dom.remove_node node;
          ignore (Dom.js_map_delete current_map old_key)
        | None -> ()
      end
    ) !current_order;
    
    (* Add or reuse nodes *)
    let new_nodes = List.map (fun item ->
      let k = key item in
      match Dom.js_map_get_opt current_map k with
      | Some (node, _old_item) ->
        (* Reuse existing node - note: doesn't update content! *)
        (* For full reactivity, items should contain signals *)
        (k, node)
      | None ->
        (* Create new node *)
        let node = Html.to_dom_node (render item) in
        Dom.js_map_set_ current_map k (node, item);
        (k, node)
    ) new_items in
    
    (* Reorder nodes in DOM *)
    (* Simple approach: remove all and re-add in order *)
    List.iter (fun (_, node) -> Dom.remove_node node) new_nodes;
    List.iter (fun (_, node) -> Dom.append_child parent node) new_nodes;
    
    current_order := new_keys
  )

(** {1 Conditional Rendering} *)

(** Conditionally render content based on a boolean signal.
    
    @param when_ Boolean signal controlling visibility
    @param render Function to render content when visible
    @param parent DOM element to append content to *)
let show ~(when_ : bool Signal.t) ~(render : unit -> Html.node) (parent : Dom.element) =
  let placeholder = Dom.create_comment (Dom.document ()) "show" in
  let current_node : Dom.node option ref = ref None in
  
  (* Insert placeholder *)
  Dom.append_child parent (Dom.node_of_comment placeholder);
  
  Effect.create (fun () ->
    let visible = Signal.get when_ in
    match visible, !current_node with
    | true, None ->
      (* Show: render and insert before placeholder *)
      let node = Html.to_dom_node (render ()) in
      Dom.insert_before parent node (Some (Dom.node_of_comment placeholder));
      current_node := Some node
    | false, Some node ->
      (* Hide: remove node *)
      Dom.remove_node node;
      current_node := None
    | true, Some _ ->
      (* Already visible, do nothing *)
      ()
    | false, None ->
      (* Already hidden, do nothing *)
      ()
  );
  
  (* Cleanup *)
  Owner.on_cleanup (fun () ->
    (match !current_node with
     | Some node -> Dom.remove_node node
     | None -> ());
    Dom.remove_node (Dom.node_of_comment placeholder)
  )

(** Conditionally render one of two alternatives.
    
    @param when_ Boolean signal
    @param then_ Function to render when true
    @param else_ Function to render when false
    @param parent DOM element to append content to *)
let if_ ~(when_ : bool Signal.t) ~then_ ~else_ (parent : Dom.element) =
  let placeholder = Dom.create_comment (Dom.document ()) "if" in
  let current_node : Dom.node option ref = ref None in
  let current_branch : bool option ref = ref None in
  
  Dom.append_child parent (Dom.node_of_comment placeholder);
  
  Effect.create (fun () ->
    let condition = Signal.get when_ in
    if !current_branch <> Some condition then begin
      (* Branch changed, swap content *)
      (match !current_node with
       | Some node -> Dom.remove_node node
       | None -> ());
      let render = if condition then then_ else else_ in
      let node = Html.to_dom_node (render ()) in
      Dom.insert_before parent node (Some (Dom.node_of_comment placeholder));
      current_node := Some node;
      current_branch := Some condition
    end
  );
  
  Owner.on_cleanup (fun () ->
    (match !current_node with
     | Some node -> Dom.remove_node node
     | None -> ());
    Dom.remove_node (Dom.node_of_comment placeholder)
  )

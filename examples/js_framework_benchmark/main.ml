(** js-framework-benchmark implementation for solid-ml
    
    This implements the standard benchmark operations using solid-ml's
    reactive primitives (signals, effects, batch, selector) matching SolidJS.
    
    - Create 1,000 rows
    - Create 10,000 rows  
    - Append 1,000 rows
    - Update every 10th row
    - Clear rows
    - Swap rows (row 2 and row 999)
    - Select row
    - Remove row
*)

open Solid_ml_browser

(** {1 Data Generation} *)

let adjectives = [|
  "pretty"; "large"; "big"; "small"; "tall"; "short"; "long"; "handsome";
  "plain"; "quaint"; "clean"; "elegant"; "easy"; "angry"; "crazy"; "helpful";
  "mushy"; "odd"; "unsightly"; "adorable"; "important"; "inexpensive"; "cheap";
  "expensive"; "fancy"
|]

let colors = [|
  "red"; "yellow"; "blue"; "green"; "pink"; "brown"; "purple"; "brown";
  "white"; "black"; "orange"
|]

let nouns = [|
  "table"; "chair"; "house"; "bbq"; "desk"; "car"; "pony"; "cookie";
  "sandwich"; "burger"; "pizza"; "mouse"; "keyboard"
|]

(* Match SolidJS random exactly for benchmark parity *)
let random max = 
  (int_of_float ((Random.float 1.0) *. 1000.0 +. 0.5)) mod max

let next_id = ref 1

(** Row data with a signal for the label (like SolidJS) *)
type row = {
  id : int;
  label : string Reactive.Signal.t;
  set_label : string -> unit;
}

let build_data count =
  Array.init count (fun _ ->
    let initial_label = 
      adjectives.(random (Array.length adjectives)) ^ " " ^
      colors.(random (Array.length colors)) ^ " " ^
      nouns.(random (Array.length nouns))
    in
    let label, set_label = Reactive.Signal.create initial_label in
    let id = !next_id in
    incr next_id;
    { id; label; set_label }
  )

(** {1 Application State} *)

(* Main data signal - array of rows *)
let data, set_data = Reactive.Signal.create [||]

(* Selected row ID signal - use -1 for "no selection" like null in JS *)
let selected, set_selected = Reactive.Signal.create (-1)

(* Create selector for O(1) selection checks instead of O(n) *)
let is_selected = Reactive.create_selector selected

(** {1 Benchmark Operations} *)

let run () =
  set_data (build_data 1000)

let run_lots () =
  set_data (build_data 10000)

let add () =
  let current = Reactive.Signal.peek data in
  set_data (Array.append current (build_data 1000))

let update_rows () =
  Reactive.Batch.run (fun () ->
    let d = Reactive.Signal.peek data in
    let len = Array.length d in
    let i = ref 0 in
    while !i < len do
      let row = d.(!i) in
      row.set_label (Reactive.Signal.peek row.label ^ " !!!");
      i := !i + 10
    done
  )

let clear () =
  set_data [||]

let swap_rows () =
  let d = Reactive.Signal.peek data in
  if Array.length d > 998 then begin
    let new_data = Array.copy d in
    let tmp = new_data.(1) in
    new_data.(1) <- new_data.(998);
    new_data.(998) <- tmp;
    set_data new_data
  end

let remove id =
  let d = Reactive.Signal.peek data in
  let len = Array.length d in
  (* Find index of item to remove *)
  let idx = ref (-1) in
  for i = 0 to len - 1 do
    if d.(i).id = id then idx := i
  done;
  if !idx >= 0 then begin
    (* Create new array without the item *)
    let new_arr = Array.init (len - 1) (fun i ->
      if i < !idx then d.(i) else d.(i + 1)
    ) in
    set_data new_arr
  end

let select id =
  set_selected id

(** {1 Row Rendering with Disposal Tracking} *)

(** Row state includes the DOM element and dispose function for cleanup *)
type row_state = {
  element : Dom.element;
  dispose : unit -> unit;
}

(** Render a single row. Uses:
    - createSelector for O(1) selection updates
    - textContent for faster text updates
    - Owner.create_root for proper disposal *)
let render_row row =
  let row_id = row.id in
  let tr = Dom.create_element Dom.document "tr" in
  Dom.set_attribute tr "data-id" (string_of_int row_id);
  
  (* Create effects within a root so we can dispose them *)
  let dispose = Reactive.Owner.create_root (fun () ->
    (* Reactive class binding using selector - O(1) instead of O(n)! *)
    Reactive.Effect.create (fun () ->
      let sel = is_selected row_id in
      Dom.set_class_name tr (if sel then "danger" else "")
    );
    
    (* TD 1: ID - static, use textContent directly *)
    let td1 = Dom.create_element Dom.document "td" in
    Dom.set_class_name td1 "col-md-1";
    Dom.set_text_content td1 (string_of_int row_id);
    Dom.append_child tr (Dom.node_of_element td1);
    
    (* TD 2: Label - reactive via signal, use textContent *)
    let td2 = Dom.create_element Dom.document "td" in
    Dom.set_class_name td2 "col-md-4";
    let a = Dom.create_element Dom.document "a" in
    (* Set initial value *)
    Dom.set_text_content a (Reactive.Signal.peek row.label);
    (* Update reactively *)
    Reactive.Effect.create (fun () ->
      Dom.set_text_content a (Reactive.Signal.get row.label)
    );
    Dom.append_child td2 (Dom.node_of_element a);
    Dom.append_child tr (Dom.node_of_element td2);
    
    (* TD 3: Delete button *)
    let td3 = Dom.create_element Dom.document "td" in
    Dom.set_class_name td3 "col-md-1";
    let a_del = Dom.create_element Dom.document "a" in
    let span = Dom.create_element Dom.document "span" in
    Dom.set_class_name span "glyphicon glyphicon-remove";
    Dom.set_attribute span "aria-hidden" "true";
    Dom.append_child a_del (Dom.node_of_element span);
    Dom.append_child td3 (Dom.node_of_element a_del);
    Dom.append_child tr (Dom.node_of_element td3);
    
    (* TD 4: Spacer *)
    let td4 = Dom.create_element Dom.document "td" in
    Dom.set_class_name td4 "col-md-6";
    Dom.append_child tr (Dom.node_of_element td4)
  ) in
  
  { element = tr; dispose }

(** {1 DOM Reconciliation Algorithm} *)

(** Reconcile two arrays of DOM nodes using the udomdiff algorithm.
    This is the same algorithm used by SolidJS (via dom-expressions).
    
    Based on: https://github.com/WebReflection/udomdiff
    
    The algorithm handles:
    - Common prefix/suffix (no moves needed)
    - Pure append/remove cases
    - Swap detection
    - General case with map-based lookup
*)
let reconcile_arrays (parent : Dom.element) (a : Dom.element array) (b : Dom.element array) =
  let b_length = Array.length b in
  let a_end = ref (Array.length a) in
  let b_end = ref b_length in
  let a_start = ref 0 in
  let b_start = ref 0 in
  
  (* Get the node after the last element in 'a', or None if at end *)
  let after = 
    if !a_end > 0 then Dom.get_next_sibling a.(!a_end - 1)
    else None
  in
  
  (* Map for fallback case - lazily initialized *)
  let map = ref None in
  
  while !a_start < !a_end || !b_start < !b_end do
    (* Common prefix - nodes match, skip them *)
    if !a_start < !a_end && !b_start < !b_end && a.(!a_start) == b.(!b_start) then begin
      incr a_start;
      incr b_start
    end
    (* Common suffix - nodes match at end, skip them *)
    else if !a_end > !a_start && !b_end > !b_start && a.(!a_end - 1) == b.(!b_end - 1) then begin
      decr a_end;
      decr b_end
    end
    (* Append case - old array exhausted, insert remaining new nodes *)
    else if !a_end = !a_start then begin
      let node =
        if !b_end < b_length then
          if !b_start > 0 then Dom.get_next_sibling b.(!b_start - 1)
          else Some (Dom.node_of_element b.(!b_end - !b_start))
        else after
      in
      while !b_start < !b_end do
        Dom.insert_before parent (Dom.node_of_element b.(!b_start)) node;
        incr b_start
      done
    end
    (* Remove case - new array exhausted, remove remaining old nodes *)
    else if !b_end = !b_start then begin
      while !a_start < !a_end do
        (* Only remove if not in the map (not being reused) *)
        let dominated = match !map with
          | None -> false
          | Some m -> Hashtbl.mem m a.(!a_start)
        in
        if not dominated then
          Dom.remove_element a.(!a_start);
        incr a_start
      done
    end
    (* Swap backward detection - first and last swapped *)
    else if !a_start < !a_end && !b_start < !b_end &&
            a.(!a_start) == b.(!b_end - 1) && b.(!b_start) == a.(!a_end - 1) then begin
      decr a_end;
      let node = Dom.get_next_sibling a.(!a_end) in
      Dom.insert_before parent (Dom.node_of_element b.(!b_start)) 
        (Dom.get_next_sibling a.(!a_start));
      incr b_start;
      incr a_start;
      decr b_end;
      Dom.insert_before parent (Dom.node_of_element b.(!b_end)) node
    end
    (* Fallback to map-based reconciliation *)
    else begin
      (* Build map lazily *)
      if !map = None then begin
        let m = Hashtbl.create (!b_end - !b_start) in
        for i = !b_start to !b_end - 1 do
          Hashtbl.replace m b.(i) i
        done;
        map := Some m
      end;
      
      let m = match !map with Some m -> m | None -> assert false in
      
      match Hashtbl.find_opt m a.(!a_start) with
      | Some index when !b_start < index && index < !b_end ->
        (* Found in new array - check for sequence *)
        let i = ref !a_start in
        let sequence = ref 1 in
        incr i;
        while !i < !a_end && !i < !b_end do
          match Hashtbl.find_opt m a.(!i) with
          | Some t when t = index + !sequence ->
            incr sequence;
            incr i
          | _ -> i := !a_end (* break *)
        done;
        
        if !sequence > index - !b_start then begin
          (* Insert nodes before current position *)
          let node = a.(!a_start) in
          while !b_start < index do
            Dom.insert_before parent (Dom.node_of_element b.(!b_start)) 
              (Some (Dom.node_of_element node));
            incr b_start
          done
        end else begin
          (* Replace node *)
          Dom.replace_child parent 
            (Dom.node_of_element b.(!b_start)) 
            (Dom.node_of_element a.(!a_start));
          incr b_start;
          incr a_start
        end
      | Some _ ->
        (* Found but outside range, skip *)
        incr a_start
      | None ->
        (* Not in new array, remove it *)
        Dom.remove_element a.(!a_start);
        incr a_start
    end
  done

(** {1 Keyed List Rendering with Optimized Reconciliation} *)

(** Efficient keyed list rendering with minimal DOM updates.
    Uses the same reconciliation algorithm as SolidJS (udomdiff). *)
let render_keyed_list ~(items : row array Reactive.Signal.t) (parent : Dom.element) =
  (* Map from row id to row state (element + dispose) - sized for 10k rows *)
  let node_map : (int, row_state) Hashtbl.t = Hashtbl.create 16384 in
  (* Track previous DOM elements for reconciliation *)
  let prev_nodes : Dom.element array ref = ref [||] in
  
  Reactive.Effect.create (fun () ->
    let new_items = Reactive.Signal.get items in
    let new_len = Array.length new_items in
    
    (* Build set of new IDs for O(1) lookup *)
    let new_id_set = Hashtbl.create new_len in
    Array.iter (fun row -> Hashtbl.replace new_id_set row.id ()) new_items;
    
    (* Dispose removed items (but don't remove from DOM yet - reconcile handles that) *)
    Hashtbl.iter (fun id state ->
      if not (Hashtbl.mem new_id_set id) then begin
        state.dispose ();
        Hashtbl.remove node_map id
      end
    ) node_map;
    
    (* Build array of nodes, creating new ones as needed *)
    let new_nodes = Array.map (fun row ->
      match Hashtbl.find_opt node_map row.id with
      | Some state -> state.element
      | None ->
        let state = render_row row in
        Hashtbl.replace node_map row.id state;
        state.element
    ) new_items in
    
    (* Reconcile DOM *)
    let prev = !prev_nodes in
    if Array.length prev = 0 && new_len > 0 then begin
      (* Initial render: just append all *)
      Array.iter (fun node ->
        Dom.append_child parent (Dom.node_of_element node)
      ) new_nodes
    end else if new_len > 0 || Array.length prev > 0 then begin
      (* Use reconciliation algorithm *)
      reconcile_arrays parent prev new_nodes
    end;
    
    (* Update previous nodes for next reconciliation *)
    prev_nodes := new_nodes
  );
  
  (* Cleanup on disposal *)
  Reactive.Owner.on_cleanup (fun () ->
    Hashtbl.iter (fun _ state ->
      state.dispose ();
      Dom.remove_child parent (Dom.node_of_element state.element)
    ) node_map;
    Hashtbl.clear node_map
  )

(** {1 Event Delegation} *)

(** Set up event delegation on the tbody for select and remove actions *)
let setup_event_delegation tbody =
  Dom.add_event_listener tbody "click" (fun evt ->
    (* Find the clicked element and its closest tr *)
    let rec find_row el =
      let tag = String.lowercase_ascii (Dom.get_tag_name el) in
      if tag = "tr" then Some el
      else if tag = "tbody" || tag = "table" then None
      else match Dom.get_parent_element el with
        | Some parent -> find_row parent
        | None -> None
    in
    
    let target = Dom.target evt in
    let tag = String.lowercase_ascii (Dom.get_tag_name target) in
    
    (* Check if this is a delete action (span with glyphicon-remove) *)
    let is_delete = 
      tag = "span" && Dom.has_class target "glyphicon-remove" ||
      tag = "a" && (match Dom.get_first_child target with
        | Some child when Dom.is_element child -> 
          Dom.has_class (Dom.element_of_node child) "glyphicon-remove"
        | _ -> false)
    in
    
    match find_row target with
    | None -> ()
    | Some tr ->
      match Dom.get_attribute tr "data-id" with
      | None -> ()
      | Some id_str ->
        let id = int_of_string id_str in
        if is_delete then remove id
        else select id
  )

(** {1 Main App} *)

let () =
  Random.self_init ();
  
  match Dom.get_element_by_id Dom.document "tbody" with
  | None -> Dom.error "tbody not found"
  | Some tbody ->
    (* Set up event delegation *)
    setup_event_delegation tbody;
    
    (* Set up keyed list rendering *)
    let _dispose = Reactive.Owner.create_root (fun () ->
      render_keyed_list ~items:data tbody
    ) in
    
    (* Button handlers *)
    let setup_button id handler =
      match Dom.get_element_by_id Dom.document id with
      | Some btn -> Dom.add_event_listener btn "click" (fun _ -> handler ())
      | None -> ()
    in
    
    setup_button "run" run;
    setup_button "runlots" run_lots;
    setup_button "add" add;
    setup_button "update" update_rows;
    setup_button "clear" clear;
    setup_button "swaprows" swap_rows

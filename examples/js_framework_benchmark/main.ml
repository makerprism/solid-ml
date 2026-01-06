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

(** {1 Keyed List Rendering with Optimized Reconciliation} *)

(** Efficient keyed list rendering with minimal DOM updates.
    Similar to SolidJS's <For> component. *)
let render_keyed_list ~(items : row array Reactive.Signal.t) (parent : Dom.element) =
  (* Map from row id to row state (element + dispose) - sized for 10k rows *)
  let node_map : (int, row_state) Hashtbl.t = Hashtbl.create 16384 in
  (* Track previous order for minimal reordering *)
  let prev_ids : int array ref = ref [||] in
  
  Reactive.Effect.create (fun () ->
    let new_items = Reactive.Signal.get items in
    let new_len = Array.length new_items in
    
    (* Build set of new IDs for O(1) lookup *)
    let new_id_set = Hashtbl.create new_len in
    Array.iter (fun row -> Hashtbl.replace new_id_set row.id ()) new_items;
    
    (* Remove nodes that are no longer in the list and dispose their effects *)
    Hashtbl.iter (fun id state ->
      if not (Hashtbl.mem new_id_set id) then begin
        state.dispose ();
        Dom.remove_child parent (Dom.node_of_element state.element);
        Hashtbl.remove node_map id
      end
    ) node_map;
    
    (* Build array of nodes, creating new ones as needed *)
    let nodes = Array.map (fun row ->
      match Hashtbl.find_opt node_map row.id with
      | Some state -> state.element
      | None ->
        let state = render_row row in
        Hashtbl.replace node_map row.id state;
        state.element
    ) new_items in
    
    (* Optimized reconciliation: only move nodes that are out of order *)
    let prev = !prev_ids in
    let prev_len = Array.length prev in
    
    if prev_len = 0 then begin
      (* Initial render: just append all *)
      Array.iter (fun node ->
        Dom.append_child parent (Dom.node_of_element node)
      ) nodes
    end else if new_len = 0 then begin
      (* Already handled by removal above *)
      ()
    end else begin
      (* Build position map for previous order *)
      let prev_pos = Hashtbl.create prev_len in
      Array.iteri (fun i id -> Hashtbl.replace prev_pos id i) prev;
      
      (* Get the position each new item had in prev (or -1 if new) *)
      let positions = Array.map (fun row ->
        match Hashtbl.find_opt prev_pos row.id with
        | Some p -> p
        | None -> -1  (* New item *)
      ) new_items in
      
      (* Find nodes that need to be moved using a simple approach:
         Track max position seen; anything less needs to move *)
      let max_pos = ref (-1) in
      let needs_move = Array.map (fun pos ->
        if pos = -1 then begin
          (* New node, needs to be inserted *)
          true
        end else if pos < !max_pos then begin
          (* Out of order, needs move *)
          true
        end else begin
          (* In order, update max *)
          max_pos := pos;
          false
        end
      ) positions in
      
      (* Now insert/move nodes that need it *)
      for i = 0 to new_len - 1 do
        if needs_move.(i) then begin
          let node = nodes.(i) in
          let ref_node = 
            if i + 1 < new_len then Some (Dom.node_of_element nodes.(i + 1))
            else None
          in
          Dom.insert_before parent (Dom.node_of_element node) ref_node
        end
      done
    end;
    
    (* Update previous IDs for next reconciliation *)
    prev_ids := Array.map (fun row -> row.id) new_items
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

(** js-framework-benchmark implementation for solid-ml
    
    This implements the standard benchmark operations using solid-ml's
    reactive primitives (signals, effects, batch) similar to SolidJS.
    
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

let random max = 
  (Random.int 1000) mod max

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

(* Selected row ID signal *)
let selected, set_selected = Reactive.Signal.create (-1)

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
  set_data (Array.of_list (
    Array.to_list d |> List.filter (fun row -> row.id <> id)
  ))

let select id =
  set_selected id

(** {1 Row Rendering} *)

(** Render a single row. The label is reactive via signal. *)
let render_row row =
  let row_id = row.id in
  let tr = Dom.create_element Dom.document "tr" in
  
  (* Reactive class binding for selection *)
  Reactive.Effect.create (fun () ->
    let sel = Reactive.Signal.get selected in
    Dom.set_class_name tr (if sel = row_id then "danger" else "")
  );
  
  (* TD 1: ID *)
  let td1 = Dom.create_element Dom.document "td" in
  Dom.set_attribute td1 "class" "col-md-1";
  Dom.node_set_text_content (Dom.node_of_element td1) (string_of_int row_id);
  Dom.append_child tr (Dom.node_of_element td1);
  
  (* TD 2: Label with reactive text *)
  let td2 = Dom.create_element Dom.document "td" in
  Dom.set_attribute td2 "class" "col-md-4";
  let a = Dom.create_element Dom.document "a" in
  Dom.add_event_listener a "click" (fun _ -> select row_id);
  (* Reactive text content *)
  let text_node = Dom.create_text_node Dom.document (Reactive.Signal.peek row.label) in
  Reactive.Effect.create (fun () ->
    Dom.text_set_data text_node (Reactive.Signal.get row.label)
  );
  Dom.append_child a (Dom.node_of_text text_node);
  Dom.append_child td2 (Dom.node_of_element a);
  Dom.append_child tr (Dom.node_of_element td2);
  
  (* TD 3: Delete button *)
  let td3 = Dom.create_element Dom.document "td" in
  Dom.set_attribute td3 "class" "col-md-1";
  let a_del = Dom.create_element Dom.document "a" in
  Dom.add_event_listener a_del "click" (fun _ -> remove row_id);
  let span = Dom.create_element Dom.document "span" in
  Dom.set_attribute span "class" "glyphicon glyphicon-remove";
  Dom.set_attribute span "aria-hidden" "true";
  Dom.append_child a_del (Dom.node_of_element span);
  Dom.append_child td3 (Dom.node_of_element a_del);
  Dom.append_child tr (Dom.node_of_element td3);
  
  (* TD 4: Spacer *)
  let td4 = Dom.create_element Dom.document "td" in
  Dom.set_attribute td4 "class" "col-md-6";
  Dom.append_child tr (Dom.node_of_element td4);
  
  tr

(** {1 Keyed List Rendering} *)

(** Efficient keyed list rendering with minimal DOM updates.
    Similar to SolidJS's <For> component. *)
let render_keyed_list ~(items : row array Reactive.Signal.t) (parent : Dom.element) =
  (* Map from row id to DOM element *)
  let node_map : (int, Dom.element) Hashtbl.t = Hashtbl.create 1024 in
  
  Reactive.Effect.create (fun () ->
    let new_items = Reactive.Signal.get items in
    
    (* Build set of new IDs for O(1) lookup *)
    let new_id_set = Hashtbl.create (Array.length new_items) in
    Array.iter (fun row -> Hashtbl.replace new_id_set row.id ()) new_items;
    
    (* Remove nodes that are no longer in the list *)
    let to_remove = Hashtbl.fold (fun id node acc ->
      if not (Hashtbl.mem new_id_set id) then (id, node) :: acc else acc
    ) node_map [] in
    List.iter (fun (id, node) ->
      Dom.remove_child parent (Dom.node_of_element node);
      Hashtbl.remove node_map id
    ) to_remove;
    
    (* Get or create nodes for all items, appending new ones *)
    let nodes = Array.map (fun row ->
      match Hashtbl.find_opt node_map row.id with
      | Some node -> node
      | None ->
        let node = render_row row in
        Hashtbl.replace node_map row.id node;
        (* New nodes get appended - will be reordered below *)
        Dom.append_child parent (Dom.node_of_element node);
        node
    ) new_items in
    
    (* Reorder nodes to match new_items order *)
    (* Simple but correct: iterate and insertBefore the next expected node *)
    let len = Array.length nodes in
    if len > 0 then begin
      (* Use a reference node approach: insert each node before the next one *)
      for i = len - 2 downto 0 do
        let node = nodes.(i) in
        let next_node = nodes.(i + 1) in
        (* Only move if not already in correct position *)
        let prev_sibling = Dom.get_next_sibling node in
        if prev_sibling <> Some (Dom.node_of_element next_node) then
          Dom.insert_before parent (Dom.node_of_element node) (Some (Dom.node_of_element next_node))
      done
    end
  );
  
  (* Cleanup *)
  Reactive.Owner.on_cleanup (fun () ->
    Hashtbl.iter (fun _ node ->
      Dom.remove_child parent (Dom.node_of_element node)
    ) node_map;
    Hashtbl.clear node_map
  )

(** {1 Main App} *)

let () =
  Random.self_init ();
  
  match Dom.get_element_by_id Dom.document "tbody" with
  | None -> Dom.error "tbody not found"
  | Some tbody ->
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

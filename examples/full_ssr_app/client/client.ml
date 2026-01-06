(** Full SSR App Example - Client Hydration
    
    This script hydrates the server-rendered HTML to make it interactive.
    It attaches event handlers to existing DOM elements and sets up
    client-side navigation.
    
    Build with: make example-full-ssr-client
*)

open Solid_ml_browser

(** {1 Shared Data Types} *)

type todo = {
  id : int;
  text : string;
  completed : bool;
}

(** {1 DOM Helpers} *)

let get_element id =
  Dom.get_element_by_id Dom.document id

let query_selector selector =
  Dom.query_selector Dom.document selector

let query_selector_all selector =
  Dom.query_selector_all Dom.document selector

(** {1 Client-Side Navigation} *)

(** Set up client-side navigation for all nav links *)
let setup_navigation () =
  let nav_links = query_selector_all "nav a.nav-link" in
  List.iter (fun link ->
    let href = Dom.get_attribute link "href" in
    match href with
    | Some path ->
      Dom.add_event_listener link "click" (fun evt ->
        Dom.prevent_default evt;
        (* For this demo, just do a full navigation *)
        (* In a real app, you'd use the Router module *)
        Dom.set_location path
      )
    | None -> ()
  ) nav_links

(** {1 Counter Hydration} *)

let hydrate_counter () =
  match get_element "counter-value", get_element "initial-count" with
  | Some counter_el, Some initial_el ->
    (* Get initial value from hidden input *)
    let initial = 
      match Dom.get_attribute initial_el "value" with
      | Some v -> (try int_of_string v with _ -> 0)
      | None -> 0
    in
    
    (* Create reactive state *)
    let count, set_count = Reactive.Signal.create initial in
    
    (* Update the counter display reactively *)
    Reactive.Effect.create (fun () ->
      let value = Reactive.Signal.get count in
      Dom.set_inner_html counter_el (string_of_int value)
    );
    
    (* Attach button handlers *)
    (match get_element "decrement" with
     | Some btn -> 
       Dom.add_event_listener btn "click" (fun _ ->
         Reactive.Signal.update count (fun n -> n - 1)
       )
     | None -> ());
    
    (match get_element "increment" with
     | Some btn ->
       Dom.add_event_listener btn "click" (fun _ ->
         Reactive.Signal.update count (fun n -> n + 1)
       )
     | None -> ());
    
    (match get_element "reset" with
     | Some btn ->
       Dom.add_event_listener btn "click" (fun _ ->
         set_count initial
       )
     | None -> ());
    
    Dom.log "Counter hydrated!"
  | _ -> ()

(** {1 Todo List Hydration} *)

(** Extract todo ID from element id like "todo-123" *)
let extract_todo_id el =
  match Dom.get_attribute el "id" with
  | Some id_str when String.length id_str > 5 && String.sub id_str 0 5 = "todo-" ->
    (try Some (int_of_string (String.sub id_str 5 (String.length id_str - 5))) with _ -> None)
  | _ -> None

let hydrate_todos () =
  match get_element "todo-list" with
  | Some list_el ->
    (* Get all todo items and their IDs *)
    let items = Dom.query_selector_all_within list_el "li.todo-item" in
    
    (* Create reactive state for todos *)
    let initial_todos = List.filter_map (fun item ->
      match extract_todo_id item with
      | Some id ->
        let completed = Dom.has_class item "completed" in
        let text = 
          match Dom.query_selector_within item "span" with
          | Some span -> Dom.get_inner_text span
          | None -> ""
        in
        Some { id; text; completed }
      | None -> None
    ) items in
    
    let todos, _set_todos = Reactive.Signal.create initial_todos in
    
    (* Compute incomplete count *)
    let incomplete_count = Reactive.Memo.create (fun () ->
      List.filter (fun t -> not t.completed) (Reactive.Signal.get todos)
      |> List.length
    ) in
    
    (* Update status text *)
    (match query_selector ".status" with
     | Some status_el ->
       Reactive.Effect.create (fun () ->
         let count = Reactive.Memo.get incomplete_count in
         Dom.set_inner_html status_el (string_of_int count ^ " items remaining")
       )
     | None -> ());
    
    (* Attach checkbox handlers *)
    List.iter (fun item ->
      match extract_todo_id item with
      | Some id ->
        (match Dom.query_selector_within item "input[type='checkbox']" with
         | Some checkbox ->
           Dom.add_event_listener checkbox "change" (fun _ ->
             Reactive.Signal.update todos (fun ts ->
               List.map (fun t ->
                 if t.id = id then { t with completed = not t.completed }
                 else t
               ) ts
             );
             (* Update the item's class *)
             let is_completed = 
               List.exists (fun t -> t.id = id && t.completed) 
                 (Reactive.Signal.get todos)
             in
             if is_completed then
               Dom.add_class item "completed"
             else
               Dom.remove_class item "completed"
           )
         | None -> ())
      | None -> ()
    ) items;
    
    Dom.log "Todos hydrated!"
  | None -> ()

(** {1 Show Hydration Status} *)

let show_hydration_status () =
  match get_element "hydration-status" with
  | Some el -> Dom.add_class el "active"
  | None -> ()

(** {1 Main Entry Point} *)

let () =
  (* Initialize the reactive runtime *)
  let (_result, _dispose) = Reactive_core.create_root (fun () ->
    let path = Dom.get_pathname () in
    Dom.log ("Hydrating page: " ^ path);
    
    (* Hydrate based on current page *)
    if path = "/counter" then
      hydrate_counter ()
    else if path = "/todos" then
      hydrate_todos ();
    
    (* Set up client-side navigation for all pages *)
    setup_navigation ();
    
    (* Show hydration status *)
    show_hydration_status ();
    
    Dom.log "Hydration complete!"
  ) in
  ()

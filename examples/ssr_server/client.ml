(** Client-side hydration for SSR example.
    
    This script runs in the browser after the server-rendered HTML loads.
    It hydrates the static HTML to make it interactive.
    
    Build with: make example-ssr-client
*)

open Solid_ml_browser

(** Counter component - must match the server-side structure *)
let counter_component ~initial () =
  let count, set_count = Reactive.Signal.create initial in
  let doubled = Reactive.Memo.create (fun () -> Reactive.Signal.get count * 2) in
  
  Html.(
    div ~class_:"counter" ~children:[
      h1 ~children:[text "Interactive Counter"] ();
      p ~children:[text "Click the buttons to change the count:"] ();
      
      div ~class_:"count" ~children:[
        Reactive.text count
      ] ();
      
      div ~class_:"buttons" ~children:[
        button ~class_:"btn" ~onclick:(fun _ -> 
          Reactive.Signal.update count (fun n -> n - 1)
        ) ~children:[text "-"] ();
        button ~class_:"btn" ~onclick:(fun _ -> 
          Reactive.Signal.update count (fun n -> n + 1)
        ) ~children:[text "+"] ();
        button ~class_:"btn btn-reset" ~onclick:(fun _ -> set_count initial) 
          ~children:[text "Reset"] ();
      ] ();
      
      p ~children:[
        text "Doubled: ";
        Reactive.memo_text doubled;
      ] ();
      
      p ~class_:"hydrated-notice" ~children:[
        text "This counter is now interactive! (hydrated from server HTML)"
      ] ();
    ] ()
  )

(** Todo item type - must match server *)
type todo = {
  id: int;
  text: string;
  completed: bool;
}

(** Todo component - interactive version *)
let todo_component ~initial_todos () =
  let todos, _set_todos = Reactive.Signal.create initial_todos in
  
  let toggle_todo id =
    Reactive.Signal.update todos (fun ts ->
      List.map (fun t ->
        if t.id = id then { t with completed = not t.completed }
        else t
      ) ts
    )
  in
  
  let incomplete_count = Reactive.Memo.create (fun () ->
    List.filter (fun t -> not t.completed) (Reactive.Signal.get todos)
    |> List.length
  ) in
  
  (* Create todo list container *)
  let todo_list_el = Dom.create_element Dom.document "div" in
  
  (* Set up reactive list rendering *)
  Reactive.each ~items:todos ~render:(fun todo ->
    let item_class = if todo.completed then "todo-item completed" else "todo-item" in
    Html.(
      div ~class_:item_class ~children:[
        input 
          ~type_:"checkbox" 
          ~checked:todo.completed 
          ~onchange:(fun _ -> toggle_todo todo.id)
          ();
        span ~children:[text (" " ^ todo.text)] ();
      ] ()
    )
  ) todo_list_el;
  
  Html.(
    fragment [
      h1 ~children:[text "Interactive Todos"] ();
      p ~children:[
        Reactive.memo_text incomplete_count;
        text " items remaining";
      ] ();
      Element todo_list_el;
      p ~class_:"hydrated-notice" ~children:[
        text "Todos are now interactive! Click checkboxes to toggle."
      ] ();
    ]
  )

(** Detect which page we're on and hydrate accordingly *)
let () =
  let path = Dom.get_pathname () in
  Dom.log ("Hydrating page: " ^ path);
  
  match Dom.get_element_by_id Dom.document "app" with
  | None -> Dom.error "Could not find #app element for hydration"
  | Some root ->
    (* For now, we replace content rather than true hydration *)
    (* True hydration would adopt existing DOM nodes *)
    if String.length path >= 8 && String.sub path 0 8 = "/counter" then begin
      (* Parse initial count from URL or data attribute *)
      let initial = 
        match Dom.get_search () with
        | "" -> 0
        | search ->
          (* Parse ?count=N *)
          let search = String.sub search 1 (String.length search - 1) in
          let parts = String.split_on_char '&' search in
          let count_part = List.find_opt (fun s -> 
            String.length s > 6 && String.sub s 0 6 = "count="
          ) parts in
          match count_part with
          | Some s -> 
            (try int_of_string (String.sub s 6 (String.length s - 6)) 
             with _ -> 0)
          | None -> 0
      in
      let _dispose = Render.render root (fun () -> 
        Html.(fragment [
          nav ~children:[
            a ~href:"/" ~children:[text "Home"] ();
            a ~href:"/counter" ~children:[text "Counter"] ();
            a ~href:"/todos" ~children:[text "Todos"] ();
          ] ();
          counter_component ~initial ()
        ])
      ) in
      Dom.log "Counter hydrated!"
    end
    else if path = "/todos" then begin
      (* Sample todos - in real app, this would come from server-embedded data *)
      let initial_todos = [
        { id = 1; text = "Learn OCaml"; completed = true };
        { id = 2; text = "Build solid-ml app"; completed = false };
        { id = 3; text = "Add client-side hydration"; completed = false };
        { id = 4; text = "Deploy to production"; completed = false };
      ] in
      let _dispose = Render.render root (fun () ->
        Html.(fragment [
          nav ~children:[
            a ~href:"/" ~children:[text "Home"] ();
            a ~href:"/counter" ~children:[text "Counter"] ();
            a ~href:"/todos" ~children:[text "Todos"] ();
          ] ();
          todo_component ~initial_todos ()
        ])
      ) in
      Dom.log "Todos hydrated!"
    end
    else begin
      Dom.log "Home page - no hydration needed (static content)"
    end

(** Interactive counter example for the browser.
    
    This example demonstrates:
    - Client-side rendering with solid-ml-browser
    - Reactive text updates
    - Event handling via element attributes
    - Two-way form bindings
    - List rendering with For component
    
    Build with: dune build @melange
    Then open index.html in a browser.
*)

open Solid_ml_browser

(** Simple counter component *)
let counter () =
  let count, set_count = Reactive.Signal.create 0 in
  let doubled = Reactive.Memo.create (fun () -> Reactive.Signal.get count * 2) in
  
  Html.(
    div ~id:"counter" ~class_:"counter-app" ~children:[
      h1 ~children:[text "solid-ml Counter"] ();
      
      div ~class_:"display" ~children:[
        p ~children:[
          text "Count: ";
          Reactive.reactive_text count;
        ] ();
        p ~children:[
          text "Doubled: ";
          Reactive.memo_text doubled;
        ] ();
      ] ();
      
      div ~class_:"buttons" ~children:[
        button 
          ~class_:"btn" 
          ~onclick:(fun _ -> ignore (Reactive.Signal.update count (fun n -> n - 1)))
          ~children:[text "-"] 
          ();
        button 
          ~class_:"btn" 
          ~onclick:(fun _ -> ignore (Reactive.Signal.update count (fun n -> n + 1)))
          ~children:[text "+"] 
          ();
        button 
          ~class_:"btn btn-reset" 
          ~onclick:(fun _ -> ignore (set_count 0))
          ~children:[text "Reset"] 
          ();
      ] ();
    ] ()
  )

(** Todo item type *)
type todo = {
  id: int;
  text: string;
  completed: bool;
}

(** Todo list component *)
let todo_list () =
  let todos, _set_todos = Reactive.Signal.create [
    { id = 0; text = "Learn solid-ml"; completed = false };
    { id = 1; text = "Build something cool"; completed = false };
  ] in
  let next_id = ref 2 in
  let new_todo_text, set_new_todo_text = Reactive.Signal.create "" in
  
  let add_todo () =
    let text = Reactive.Signal.get new_todo_text in
    if String.length text > 0 then begin
      let id = !next_id in
      incr next_id;
      ignore (Reactive.Signal.update todos (fun ts -> ts @ [{ id; text; completed = false }]));
      ignore (set_new_todo_text "")
    end
  in
  
  let toggle_todo id =
    ignore
      (Reactive.Signal.update todos (fun ts ->
         List.map (fun t ->
           if t.id = id then { t with completed = not t.completed }
           else t
         ) ts
       ))
  in
  
  let remove_todo id =
    ignore
      (Reactive.Signal.update todos (fun ts ->
         List.filter (fun t -> t.id <> id) ts
       ))
  in
  
  let incomplete_count = Reactive.Memo.create (fun () ->
    List.filter (fun t -> not t.completed) (Reactive.Signal.get todos)
    |> List.length
  ) in
  
  let todo_input =
    Html.input 
      ~type_:"text" 
      ~placeholder:"What needs to be done?"
      ~onkeydown:(fun evt ->
        if Event.Keyboard.is_enter evt then add_todo ()
      )
      ()
  in
  (* Bind input value to signal for two-way updates *)
  (match Html.get_element todo_input with
   | Some el -> Reactive.bind_input el new_todo_text set_new_todo_text
   | None -> ());

  let todo_list_ul =
    Html.ul ~class_:"todo-list" ~children:[] ()
  in
  (match Html.get_element todo_list_ul with
   | Some el ->
     Reactive.each
       ~items:todos
       ~render:(fun todo ->
         let item_class =
           if todo.completed then "todo-item completed" else "todo-item"
         in
          Html.li ~class_:item_class ~children:[
            Html.label ~class_:"todo-label" ~children:[
              Html.input
                ~type_:"checkbox"
                ~checked:todo.completed
                ~onchange:(fun _ -> toggle_todo todo.id)
                ();
              Html.span ~children:[Html.text todo.text] ();
            ] ();
            Html.button
              ~class_:"delete"
              ~onclick:(fun _ -> remove_todo todo.id)
              ~children:[Html.text "x"]
              ();
          ] ())
       el
   | None -> ());

  Html.(
    div ~id:"todos" ~class_:"todo-app" ~children:[
      h1 ~children:[text "Todo List"] ();
      
      (* Add todo form *)
      div ~class_:"add-todo" ~children:[
        todo_input;
        button 
          ~onclick:(fun _ -> add_todo ())
          ~children:[text "Add"] 
          ();
      ] ();
      
      (* Status *)
      p ~class_:"status" ~children:[
        Reactive.memo_text incomplete_count;
        text " items left";
      ] ();
      
      (* Todo list using keyed rendering *)
      todo_list_ul;
    ] ()
  )

(** Main entry point *)
let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some root ->
    (* Render the component and get the dispose function *)
    let dispose = Render.render root (fun () ->
      Html.fragment [
        counter ();
        Html.hr ();
        todo_list ();
      ]
    ) in

    (* IMPORTANT: Register cleanup on page unload to prevent memory leaks *)
    Dom.on_unload (fun _evt ->
      dispose ();
      Dom.log "solid-ml app disposed!"
    );

    Dom.log "solid-ml app mounted!"
  | None ->
    Dom.error "Could not find #app element"

(** Interactive counter example for the browser.
    
    This example demonstrates:
    - Client-side rendering with solid-ml-dom
    - Reactive text updates
    - Event handling via element attributes
    - Two-way form bindings
    
    Build with: dune build @melange
    Then open index.html in a browser.
*)

open Solid_ml_browser
open Reactive

(** Simple counter component *)
let counter () =
  let count, set_count = Signal.create 0 in
  let doubled = Memo.create (fun () -> Signal.get count * 2) in
  
  Html.(
    div ~id:"counter" ~class_:"counter-app" ~children:[
      h1 ~children:[Html.text "solid-ml Counter"] ();
      
      div ~class_:"display" ~children:[
        p ~children:[
          Html.text "Count: ";
          Reactive.text count;
        ] ();
        p ~children:[
          Html.text "Doubled: ";
          Reactive.memo_text doubled;
        ] ();
      ] ();
      
      div ~class_:"buttons" ~children:[
        button 
          ~class_:"btn" 
          ~onclick:(fun _ -> Signal.update count (fun n -> n - 1))
          ~children:[Html.text "-"] 
          ();
        button 
          ~class_:"btn" 
          ~onclick:(fun _ -> Signal.update count (fun n -> n + 1))
          ~children:[Html.text "+"] 
          ();
        button 
          ~class_:"btn btn-reset" 
          ~onclick:(fun _ -> set_count 0)
          ~children:[Html.text "Reset"] 
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
  let todos, _set_todos = Signal.create [
    { id = 0; text = "Learn solid-ml"; completed = false };
    { id = 1; text = "Build something cool"; completed = false };
  ] in
  let next_id = ref 2 in
  let new_todo_text, set_new_todo_text = Signal.create "" in
  
  let add_todo () =
    let text = Signal.get new_todo_text in
    if String.length text > 0 then begin
      let id = !next_id in
      incr next_id;
      Signal.update todos (fun ts -> ts @ [{ id; text; completed = false }]);
      set_new_todo_text ""
    end
  in
  
  let toggle_todo id =
    Signal.update todos (fun ts ->
      List.map (fun t ->
        if t.id = id then { t with completed = not t.completed }
        else t
      ) ts
    )
  in
  
  let remove_todo id =
    Signal.update todos (fun ts ->
      List.filter (fun t -> t.id <> id) ts
    )
  in
  
  let incomplete_count = Memo.create (fun () ->
    List.filter (fun t -> not t.completed) (Signal.get todos)
    |> List.length
  ) in
  
  (* Create the todo list container *)
  let todo_list_el = Dom.create_element Dom.document "ul" in
  Dom.set_attribute todo_list_el "class" "todo-list";
  
  (* Set up reactive list rendering *)
  Reactive.each ~items:todos ~render:(fun todo ->
    let item_class = if todo.completed then "todo-item completed" else "todo-item" in
    Html.(
      li ~class_:item_class ~children:[
        input 
          ~type_:"checkbox" 
          ~checked:todo.completed 
          ~onchange:(fun _ -> toggle_todo todo.id)
          ();
        span ~children:[Html.text todo.text] ();
        button 
          ~class_:"delete" 
          ~onclick:(fun _ -> remove_todo todo.id)
          ~children:[Html.text "x"] 
          ();
      ] ()
    )
  ) todo_list_el;
  
  Html.(
    div ~id:"todos" ~class_:"todo-app" ~children:[
      h1 ~children:[Html.text "Todo List"] ();
      
      (* Add todo form *)
      div ~class_:"add-todo" ~children:[
        input 
          ~type_:"text" 
          ~placeholder:"What needs to be done?"
          ~oninput:(fun evt -> set_new_todo_text (Dom.input_value evt))
          ~onkeydown:(fun evt ->
            if Event.Keyboard.is_enter evt then add_todo ()
          )
          ();
        button 
          ~onclick:(fun _ -> add_todo ())
          ~children:[Html.text "Add"] 
          ();
      ] ();
      
      (* Status *)
      p ~class_:"status" ~children:[
        Reactive.memo_text incomplete_count;
        Html.text " items left";
      ] ();
      
      (* The todo list element we created above *)
      Element todo_list_el;
    ] ()
  )

(** Main entry point *)
let () =
  match Dom.get_element_by_id Dom.document "app" with
  | Some root ->
    let _dispose = Render.render root (fun () ->
      Html.fragment [
        counter ();
        Html.hr ();
        todo_list ();
      ]
    ) in
    Dom.log "solid-ml app mounted!"
  | None ->
    Dom.error "Could not find #app element"

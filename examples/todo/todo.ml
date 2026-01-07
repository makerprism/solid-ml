(** A todo list example demonstrating solid-ml reactive primitives.

    This example shows:
    - Managing a list of items with signals
    - Derived computations with memos
    - Batched updates
    - SSR rendering of the todo list

    Run with: dune exec examples/todo/todo.exe
*)

open Solid_ml
open Solid_ml_ssr

(** Todo item type *)
type todo = {
  id : int;
  text : string;
  completed : bool;
}

(** Helper to run example within a runtime *)
let run_example name fn =
  print_endline ("=== " ^ name ^ " ===\n");
  Runtime.run (fun () ->
    let dispose = Owner.create_root fn in
    dispose ()
  );
  print_endline ""

(** Basic todo list operations *)
let basic_todo_example () =
  run_example "Basic Todo List" (fun () ->
    (* Signal holding list of todos *)
    let todos, set_todos = Signal.create [] in
    let _ = set_todos in  (* Used via Signal.update *)
    let next_id = ref 0 in
    
    (* Derived: count of incomplete todos *)
    let incomplete_count = Memo.create (fun () ->
      List.filter (fun t -> not t.completed) (Signal.get todos)
      |> List.length
    ) in
    
    (* Derived: count of completed todos *)
    let completed_count = Memo.create (fun () ->
      List.filter (fun t -> t.completed) (Signal.get todos)
      |> List.length
    ) in
    
    (* Effect to print status changes *)
    Effect.create (fun () ->
      Printf.printf "Status: %d incomplete, %d completed\n"
        (Memo.get incomplete_count)
        (Memo.get completed_count)
    );
    
    (* Helper functions *)
    let add_todo text =
      let id = !next_id in
      incr next_id;
      Signal.update todos (fun ts -> ts @ [{ id; text; completed = false }])
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
    
    (* Simulate user actions *)
    print_endline "\n[Adding todos...]";
    add_todo "Learn OCaml";
    add_todo "Build solid-ml app";
    add_todo "Deploy to production";
    
    print_endline "\n[Completing first todo...]";
    toggle_todo 0;
    
    print_endline "\n[Completing second todo...]";
    toggle_todo 1;
    
    print_endline "\n[Removing completed todo...]";
    remove_todo 0;
    
    print_endline "\n[Final state:]";
    List.iter (fun t ->
      Printf.printf "  [%s] %s\n" 
        (if t.completed then "x" else " ") 
        t.text
    ) (Signal.get todos)
  )

(** Filter type for todo list *)
type filter = All | Active | Completed

(** Todo list with filtering *)
let filtered_todo_example () =
  run_example "Filtered Todo List" (fun () ->
    let todos, _set_todos = Signal.create [
      { id = 0; text = "Buy groceries"; completed = true };
      { id = 1; text = "Call mom"; completed = false };
      { id = 2; text = "Write code"; completed = false };
      { id = 3; text = "Go for a walk"; completed = true };
    ] in
    
    let current_filter, set_filter = Signal.create All in
    
    (* Filtered todos - only recomputes when todos or filter changes *)
    let filtered_todos = Memo.create (fun () ->
      let ts = Signal.get todos in
      match Signal.get current_filter with
      | All -> ts
      | Active -> List.filter (fun t -> not t.completed) ts
      | Completed -> List.filter (fun t -> t.completed) ts
    ) in
    
    (* Effect to display filtered list *)
    Effect.create (fun () ->
      let filter_name = match Signal.get current_filter with
        | All -> "All"
        | Active -> "Active"
        | Completed -> "Completed"
      in
      Printf.printf "Filter: %s\n" filter_name;
      List.iter (fun t ->
        Printf.printf "  [%s] %s\n" 
          (if t.completed then "x" else " ") 
          t.text
      ) (Memo.get filtered_todos);
      print_endline ""
    );
    
    print_endline "\n[Switching to Active filter...]";
    set_filter Active;
    
    print_endline "[Switching to Completed filter...]";
    set_filter Completed;
    
    print_endline "[Switching back to All...]";
    set_filter All
  )

(** Batched todo operations *)
let batched_todo_example () =
  run_example "Batched Todo Operations" (fun () ->
    let todos, set_todos = Signal.create [] in
    let status, set_status = Signal.create "Ready" in
    let effect_runs = ref 0 in
    
    (* Effect watching both signals *)
    Effect.create (fun () ->
      incr effect_runs;
      Printf.printf "[Run %d] Status: %s, Todo count: %d\n"
        !effect_runs
        (Signal.get status)
        (List.length (Signal.get todos))
    );
    
    print_endline "\n[Without batch - separate updates:]";
    set_status "Adding...";
    set_todos [{ id = 0; text = "Item 1"; completed = false }];
    
    effect_runs := 0;
    
    print_endline "\n[With batch - single notification:]";
    Batch.run (fun () ->
      set_status "Bulk adding...";
      set_todos [
        { id = 0; text = "Item 1"; completed = false };
        { id = 1; text = "Item 2"; completed = false };
        { id = 2; text = "Item 3"; completed = false };
      ]
    );
    
    Printf.printf "\nBatched operation triggered %d effect run(s)\n" !effect_runs
  )

(** SSR rendering of todo list *)
let ssr_todo_example () =
  print_endline "=== SSR Todo Rendering ===\n";
  
  let todos = [
    { id = 0; text = "Learn OCaml"; completed = true };
    { id = 1; text = "Build solid-ml app"; completed = false };
    { id = 2; text = "Deploy to production"; completed = false };
  ] in
  
  let incomplete_count = 
    List.filter (fun t -> not t.completed) todos
    |> List.length
  in
  
  let todo_component () =
    Html.(
      div ~class_:"todo-app" ~children:[
        h1 ~children:[text "My Todos"] ();
        p ~class_:"status" ~children:[
          text (Printf.sprintf "%d items left" incomplete_count)
        ] ();
        ul ~class_:"todo-list" ~children:(
          List.map (fun todo ->
            li ~class_:(if todo.completed then "completed" else "active")
              ~children:[
                input ~type_:"checkbox" ~checked:todo.completed ();
                span ~children:[text todo.text] ();
              ] ()
          ) todos
        ) ()
      ] ()
    )
  in
  
  let html = Render.to_string todo_component in
  print_endline "Generated HTML:";
  print_endline html;
  print_endline ""

(** Main entry point *)
let () =
  basic_todo_example ();
  filtered_todo_example ();
  batched_todo_example ();
  ssr_todo_example ();
  print_endline "=== All todo examples completed! ==="

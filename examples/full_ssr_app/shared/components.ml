(** Shared Components using the Platform Functor pattern
    
    This module defines the UI components (Counter, TodoList) once,
    parameterized by the Platform interface.
*)

(** Shared Todo Type - Defined outside the functor to be accessible everywhere *)
type todo = {
  id : int;
  text : string;
  completed : bool;
}

module Make (P : Platform_intf.S) = struct
  open P

  (** Counter Component *)
  let counter ~initial () =
    let count, _ = Signal.create initial in
    
    Html.div ~class_:"counter-display" ~children:[
      Html.h2 ~children:[Html.text "Shared Counter"] ();
      
      Html.div ~children:[
        Html.reactive_text count;
      ] ();
      
      Html.div ~class_:"buttons" ~children:[
        Html.button ~class_:"btn" ~onclick:(fun _ -> Signal.update count (fun n -> n - 1)) 
          ~children:[Html.text "-"] ();
          
        Html.button ~class_:"btn" ~onclick:(fun _ -> Signal.update count (fun n -> n + 1)) 
          ~children:[Html.text "+"] ();
          
        Html.button ~class_:"btn btn-secondary" ~onclick:(fun _ -> Signal.set count initial) 
          ~children:[Html.text "Reset"] ();
      ] ()
    ] ()

  (** Todo List Component *)
  let todo_list ~initial_todos () =
    let todos, _ = Signal.create initial_todos in
    
    let incomplete_count = Memo.create (fun () ->
      List.filter (fun t -> not t.completed) (Signal.get todos)
      |> List.length
    ) in
    
    Html.div ~class_:"todo-list-container" ~children:[
      Html.h2 ~children:[Html.text "Shared Todo List"] ();
      
      Html.p ~children:[
        Html.reactive_text (Memo.as_signal incomplete_count);
        Html.text " items remaining";
      ] ();
      
      Html.ul ~class_:"todo-list" ~children:(
        (* Note: In a real app we'd use a reactive list (For/Index) 
           but for simplicity we map the signal once here. 
           (Reactivity for list changes requires more advanced handling in the shared layer) *)
        List.map (fun todo ->
          Html.li ~class_:(if todo.completed then "todo-item completed" else "todo-item") ~children:[
            Html.input ~type_:"checkbox" ~checked:todo.completed 
              ~onchange:(fun _ -> 
                Signal.update todos (fun list -> 
                  List.map (fun t -> if t.id = todo.id then {t with completed = not t.completed} else t) list
                )
              ) ();
            Html.span ~children:[Html.text todo.text] ();
          ] ()
        ) (Signal.get todos)
      ) ()
    ] ()

  (** App Layout with Navigation *)
  let app_layout ~children () =
    Html.div ~class_:"app-container" ~children:[
      Html.div ~class_:"nav" ~children:[
        Router.link ~href:"/" ~class_:"nav-link" ~children:[Html.text "Home"] ();
        Html.span ~children:[Html.text " | "] ();
        Router.link ~href:"/counter" ~class_:"nav-link" ~children:[Html.text "Counter"] ();
        Html.span ~children:[Html.text " | "] ();
        Router.link ~href:"/todo" ~class_:"nav-link" ~children:[Html.text "Todo"] ();
      ] ();
      Html.div ~class_:"content" ~children:[
        children
      ] ();
    ] ()

  (** Home Page *)
  let home_page () =
    Html.div ~children:[
      Html.h1 ~children:[Html.text "Welcome to Solid ML Isomorphic App"] ();
      Html.p ~children:[Html.text "This application runs on both server (SSR) and browser."] ();
    ] ()
end

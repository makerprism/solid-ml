(**
    Shared components for SSR + browser.
*)

type todo = {
  id : int;
  text : string;
  completed : bool;
}

module Make (Env : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV) = struct
  open Env

  module Html = Env.Html
  module Tpl = Env.Tpl
  module Routes = Routes

  open Html

  (** Keyed list demo (SSR + hydrate adoption) *)
  let keyed_demo () =
    let items, set_items = Signal.create [ "alpha"; "beta"; "gamma" ] in

    let remove_first () =
      match Signal.get items with
      | [] -> ()
      | _ :: rest -> set_items rest
    in

    let reverse () =
      set_items (List.rev (Signal.get items))
    in

    div ~children:[
      h2 ~children:[ text "Keyed Hydration Demo" ] ();
      p ~children:[ text "Try reverse/remove; DOM nodes should be adopted and reordered." ] ();

      div ~class_:"buttons" ~children:[
        button ~class_:"btn" ~onclick:(fun _ -> reverse ()) ~children:[ text "Reverse" ] ();
        button ~class_:"btn btn-secondary" ~onclick:(fun _ -> remove_first ()) ~children:[ text "Remove first" ] ();
      ] ();

      ul ~children:[
        Tpl.each_keyed
          ~items:(fun () -> Signal.get items)
          ~key:(fun s -> s)
          ~render:(fun s -> li ~id:("k-" ^ s) ~children:[ text s ] ())
      ] ()
    ] ()

  (** Counter Component *)
  let counter ~initial () =
    let count, set_count = Signal.create initial in

    div ~class_:"counter-display" ~children:[
      h2 ~children:[ text "Shared Counter" ] ();

      div ~children:[
        Tpl.text (fun () -> Int.to_string (Signal.get count))
      ] ();

      div ~class_:"buttons" ~children:[
        button ~class_:"btn" ~onclick:(fun _ -> Signal.update count (fun n -> n - 1))
          ~children:[ text "-" ] ();

        button ~class_:"btn" ~onclick:(fun _ -> Signal.update count (fun n -> n + 1))
          ~children:[ text "+" ] ();

        button ~class_:"btn btn-secondary" ~onclick:(fun _ -> set_count initial)
          ~children:[ text "Reset" ] ();
      ] ()
    ] ()

  let counter_content ~initial () =
    fragment [
      counter ~initial ();
      input ~type_:"hidden" ~id:"initial-count" ~value:(string_of_int initial) ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Counter is now interactive."
      ] ();
    ]

  (** Todo List Component *)
  let todo_list ~initial_todos () =
    let todos, set_todos = Signal.create initial_todos in

    let toggle_todo todo_id =
      set_todos
        (List.map
           (fun todo ->
             if todo.id = todo_id then { todo with completed = not todo.completed }
             else todo)
           (Signal.get todos))
    in

    div ~class_:"todo-list-container" ~children:[
      h2 ~children:[ text "Shared Todo List" ] ();

      p ~children:[
        Tpl.text (fun () ->
          Signal.get todos
          |> List.filter (fun t -> not t.completed)
          |> List.length
          |> Int.to_string);
        text " items remaining";
      ] ();

      ul ~class_:"todo-list" ~children:[
        Tpl.each_keyed
          ~items:(fun () -> Signal.get todos)
          ~key:(fun todo -> Int.to_string todo.id)
          ~render:(fun todo ->
            li ~class_:(if todo.completed then "todo-item completed" else "todo-item") ~children:[
              input ~type_:"checkbox" ~checked:todo.completed
                ~onchange:(fun _ -> toggle_todo todo.id) ();
              span ~children:[ text todo.text ] ();
            ] ())
      ] ()
    ] ()

  let todos_content ~initial_todos () =
    fragment [
      todo_list ~initial_todos ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Todos are now interactive."
      ] ();
    ]

  (** App Layout with Navigation *)
  let app_layout ~current_path ~children () =
    let nav_children =
      Routes.all
      |> List.mapi (fun index route ->
        let href = Routes.path route in
        let class_ =
          if Routes.is_active ~current_path route then "nav-link active" else "nav-link"
        in
        let link = a ~href ~class_ ~children:[ text (Routes.label route) ] () in
        if index = 0 then [ link ] else [ span ~children:[ text " | " ] (); link ])
      |> List.concat
    in
    div ~class_:"app-container" ~children:[
      div ~class_:"nav" ~children:nav_children ();
      div ~class_:"content" ~children:[ children ] ();
    ] ()

  (** Home Page *)
  let home_page () =
    div ~children:[
      h1 ~children:[ text "Welcome to Solid ML Isomorphic App" ] ();
      p ~children:[ text "This application runs on both server (SSR) and browser." ] ();
    ] ()
end

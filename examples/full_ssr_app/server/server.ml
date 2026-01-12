(** Full SSR App Example - Server
    
    This example demonstrates a complete SSR + hydration setup:
    1. Server renders HTML with reactive components (defined in Shared_components)
    2. Client hydrates the HTML to make it interactive
    3. Navigation works both server-side (full page) and client-side (SPA)
    
    Run with: make example-full-ssr
    Then visit: http://localhost:8080
*)

open Solid_ml
open Solid_ml_ssr
open Server_platform

(** {1 Shared Data Types} *)
(* We use the shared component definitions now *)
open Shared_components

let sample_todos = [
  { Components.id = 1; text = "Learn solid-ml"; completed = true };
  { Components.id = 2; text = "Build an SSR app"; completed = false };
  { Components.id = 3; text = "Add hydration"; completed = false };
  { Components.id = 4; text = "Deploy to production"; completed = false };
]

(** {1 Components} *)

(** Page layout with navigation *)
let layout ~title:page_title ~current_path ~children () =
  let nav_link href link_text =
    let is_active = current_path = href in
    Html.(
      a ~href 
        ~class_:(if is_active then "nav-link active" else "nav-link")
        ~children:[text link_text] ()
    )
  in
  
  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        raw {|<style>
          * { box-sizing: border-box; }
          body { 
            font-family: system-ui, sans-serif; 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            background: #f5f5f5;
          }
          header { 
            background: white; 
            padding: 20px; 
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          header h1 { margin: 0 0 16px 0; }
          nav { display: flex; gap: 8px; }
          .nav-link {
            padding: 8px 16px;
            text-decoration: none;
            color: #666;
            border-radius: 4px;
          }
          .nav-link:hover { background: #f0f0f0; }
          .nav-link.active { background: #4a90d9; color: white; }
          main {
            background: white;
            padding: 24px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .counter-display { 
            font-size: 48px; 
            font-weight: bold; 
            text-align: center;
            padding: 20px;
            background: #f0f0f0;
            border-radius: 8px;
            margin: 20px 0;
          }
          .buttons { display: flex; gap: 10px; justify-content: center; }
          .btn {
            padding: 10px 24px;
            font-size: 18px;
            border: none;
            border-radius: 4px;
            background: #4a90d9;
            color: white;
            cursor: pointer;
          }
          .btn:hover { background: #357abd; }
          .btn-secondary { background: #888; }
          .btn-secondary:hover { background: #666; }
          .todo-list { list-style: none; padding: 0; }
          .todo-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            border-bottom: 1px solid #eee;
          }
          .todo-item.completed span { 
            text-decoration: line-through; 
            color: #999; 
          }
          .todo-item input[type="checkbox"] {
            width: 20px;
            height: 20px;
          }
          .status { color: #666; margin-bottom: 16px; }
          footer {
            text-align: center;
            padding: 20px;
            color: #888;
            font-size: 14px;
          }
          footer a { color: #4a90d9; }
          .hydration-status {
            padding: 8px 16px;
            background: #e8f5e9;
            border-radius: 4px;
            color: #2e7d32;
            margin-top: 20px;
            display: none;
          }
          .hydration-status.active { display: block; }
        </style>|};
      ] ();
      body ~children:[
        header ~children:[
          h1 ~children:[text "solid-ml Full SSR Demo"] ();
          nav ~children:[
            nav_link "/" "Home";
            nav_link "/counter" "Counter";
            nav_link "/todos" "Todos";
          ] ();
        ] ();
        main ~id:"app" ~children ();
        footer ~children:[
          p ~children:[
            text "Powered by ";
            a ~href:"https://github.com/makerprism/solid-ml" ~children:[text "solid-ml"] ();
          ] ();
        ] ();
        (* Hydration script *)
        script ~src:"/static/client.js" ~type_:"module" ~children:[] ();
      ] ()
    ] ()
  )

(** Home page *)
let home_page () =
  layout ~title:"Home - solid-ml SSR" ~current_path:"/" ~children:Html.[
    h2 ~children:[text "Welcome to solid-ml SSR!"] ();
    p ~children:[
      text "This is a full server-side rendered application with client-side hydration."
    ] ();
    p ~children:[
      text "Features demonstrated:"
    ] ();
    ul ~children:[
      li ~children:[text "Server-side rendering with Dream"] ();
      li ~children:[text "Client-side hydration with Melange"] ();
      li ~children:[text "Shared Component Architecture (Functor-based)"] ();
      li ~children:[text "Reactive counter with signals"] ();
      li ~children:[text "Interactive todo list"] ();
      li ~children:[text "Client-side navigation (after hydration)"] ();
    ] ();
    p ~children:[
      text "Try clicking the navigation links - before hydration they do full page loads, after hydration they navigate without reloading."
    ] ();
    div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
      text "Hydrated! Navigation is now client-side."
    ] ();
  ] ()

(** Counter page - uses Shared.counter *)
let counter_page ~initial () =
  layout ~title:"Counter - solid-ml SSR" ~current_path:"/counter" ~children:[
    (* Use the shared component *)
    Shared.counter ~initial ();
    
    (* Hydration data/status *)
    Html.input ~type_:"hidden" ~id:"initial-count" ~value:(string_of_int initial) ();
    Html.div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
      Html.text "Hydrated! Counter is now interactive."
    ] ();
  ] ()

(** Todos page - uses Shared.todo_list *)
let todos_page ~todos () =
  layout ~title:"Todos - solid-ml SSR" ~current_path:"/todos" ~children:[
    (* Use the shared component *)
    Shared.todo_list ~initial_todos:todos ();

    (* Hydration status *)
    Html.div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
      Html.text "Hydrated! Todos are now interactive."
    ] ();
  ] ()

(** 404 page *)
let not_found_page ~request_path () =
  layout ~title:"Not Found - solid-ml SSR" ~current_path:request_path ~children:Html.[
    h2 ~children:[text "404 - Page Not Found"] ();
    p ~children:[
      text "The page ";
      code ~children:[text request_path] ();
      text " was not found.";
    ] ();
    p ~children:[
      a ~href:"/" ~children:[text "Go back home"] ()
    ] ();
  ] ()

(** {1 Request Handlers} *)

let handle_home _req =
  let html = Render.to_document home_page in
  Dream.html html

let handle_counter req =
  let initial = 
    Dream.query req "count"
    |> Option.map int_of_string_opt
    |> Option.join
    |> Option.value ~default:0
  in
  let html = Render.to_document (fun () -> counter_page ~initial ()) in
  Dream.html html

let handle_todos _req =
  let html = Render.to_document (fun () -> todos_page ~todos:sample_todos ()) in
  Dream.html html

let handle_not_found req =
  let path = Dream.target req in
  let html = Render.to_document (fun () -> not_found_page ~request_path:path ()) in
  Dream.html ~status:`Not_Found html

(** {1 Main Server} *)

let () =
  let port = 
    match Sys.getenv_opt "PORT" with
    | Some p -> (try int_of_string p with _ -> 8080)
    | None -> 8080
  in
  
  Printf.printf "=== solid-ml Full SSR Demo ===\n";
  Printf.printf "Server running at http://localhost:%d\n" port;
  Printf.printf "\n";
  Printf.printf "Pages:\n";
  Printf.printf "  http://localhost:%d/         - Home\n" port;
  Printf.printf "  http://localhost:%d/counter  - Counter\n" port;
  Printf.printf "  http://localhost:%d/todos    - Todos\n" port;
  Printf.printf "\n";
  Printf.printf "Build client with: make example-full-ssr-client\n";
  Printf.printf "Press Ctrl+C to stop\n";
  flush stdout;
  
  Dream.run ~port
  @@ Dream.logger
  @@ Dream.router [
    Dream.get "/" handle_home;
    Dream.get "/counter" handle_counter;
    Dream.get "/todos" handle_todos;
    Dream.get "/static/**" (Dream.static "examples/full_ssr_app/static");
    Dream.any "/**" handle_not_found;
  ]

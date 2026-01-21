(** Full SSR App Example - Server
    
    This example demonstrates a complete SSR + hydration setup:
    1. Server renders HTML with reactive components (defined in Shared_components)
    2. Client hydrates the HTML to make it interactive
    3. Navigation works both server-side (full page) and client-side (SPA)
    
    Run with: make example-full-ssr
    Then visit: http://localhost:8080
*)

open Solid_ml_ssr

(* We instantiate the shared components with the server platform *)
module Shared = Shared_components.Components.Make(Server_platform.Server_Platform)

let sample_todos = Shared_components.Components.[
  { id = 1; text = "Learn solid-ml"; completed = true };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

(** {1 Components} *)

(** Page layout with navigation - Updated to use Shared.app_layout structure *)
let layout ~title:page_title ~children () =
  (* We need to unwrap/cast the children because Server_Platform.Html.node = Solid_ml_ssr.Html.node *)
  let children_list = [children] in

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
          .app-container {
             background: white; 
             padding: 20px;
             border-radius: 8px;
             box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .nav { 
             margin-bottom: 20px; 
             padding-bottom: 10px;
             border-bottom: 1px solid #eee;
          }
          .nav-link {
            text-decoration: none;
            color: #4a90d9;
            font-weight: bold;
          }
          .nav-link:hover { text-decoration: underline; }
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
        (* App root for true hydration *)
        Html.div ~id:"app" ~children:children_list ();
        
        (* Hydration script *)
        script ~src:"/static/client.js" ~type_:"module" ~children:[] ();
      ] ()
    ] ()
  )

(** Home page *)
let home_page () =
  layout ~title:"Home - solid-ml SSR" ~children:(
    Shared.app_layout ~children:(
      Shared.home_page ()
    ) ()
  ) ()

(** Counter page - uses Shared.counter *)
let counter_page ~initial () =
  layout ~title:"Counter - solid-ml SSR" ~children:(
    Shared.app_layout ~children:(
      Shared.counter_content ~initial ()
    ) ()
  ) ()

(** Todos page - uses Shared.todo_list *)
let todos_page ~todos () =
  layout ~title:"Todos - solid-ml SSR" ~children:(
    Shared.app_layout ~children:(
      Shared.todos_content ~initial_todos:todos ()
    ) ()
  ) ()

(** 404 page *)
let not_found_page ~request_path () =
  layout ~title:"Not Found - solid-ml SSR" ~children:(
    Shared.app_layout ~children:(
      Html.div ~children:[
        Html.h2 ~children:[Html.text "404 - Page Not Found"] ();
        Html.p ~children:[
          Html.text ("The page " ^ request_path ^ " was not found.");
        ] ();
      ] ()
    ) ()
  ) ()

(** {1 Request Handlers} *)

let handle_home _req =
  let html = Render.to_document home_page in
  Dream.html html

let handle_keyed _req =
  let html =
    Render.to_document (fun () ->
      layout ~title:"Keyed - solid-ml SSR" ~children:(
        Shared.app_layout ~children:(
          Shared.keyed_demo ()
        ) ()
      ) ())
  in
  Dream.html html

let handle_template_keyed _req =
  let module T = Shared_components.Template_keyed.Make (Solid_ml_ssr.Env) in
  let html =
    Render.to_document (fun () ->
      layout ~title:"Template-Keyed - solid-ml SSR" ~children:(
        Shared.app_layout ~children:(
          T.view ()
        ) ()
      ) ())
  in
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
    Dream.get "/keyed" handle_keyed;
    Dream.get "/template-keyed" handle_template_keyed;
    Dream.get "/static/**" (Dream.static "examples/full_ssr_app/static");
    Dream.any "/**" handle_not_found;
  ]

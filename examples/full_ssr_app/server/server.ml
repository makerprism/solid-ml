(** Full SSR App Example - Server
    
    This example demonstrates a complete SSR + hydration setup:
    1. Server renders HTML with reactive components (defined in Shared_components)
    2. Client hydrates the HTML to make it interactive
    3. Navigation works both server-side (full page) and client-side (SPA)
    
    Run with: make example-full-ssr
    Then visit: http://localhost:8080
*)

open Solid_ml_ssr

module Shared = Shared_components.Components.Make(Solid_ml_ssr.Env)
module Routes = Shared_components.Routes
module Filters = Shared_components.Filters.Make(Solid_ml_ssr.Env)
module Inline_edit = Shared_components.Inline_edit.Make(Solid_ml_ssr.Env)

let sample_todos = Shared_components.Components.[
  { id = 1; text = "Learn solid-ml"; completed = true };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

let sample_todos_filters : Shared_components.Filters.todo list = [
  { id = 1; text = "Learn solid-ml"; completed = true };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

let sample_todos_inline_edit : Shared_components.Inline_edit.todo list = [
  { id = 1; text = "Learn solid-ml"; completed = false };
  { id = 2; text = "Build an SSR app"; completed = false };
  { id = 3; text = "Add inline editing"; completed = false };
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
          .nav-link.active {
            color: #1f5c9c;
            text-decoration: underline;
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
          .todo {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            border-bottom: 1px solid #eee;
            cursor: pointer;
            user-select: none;
          }
          .todo:hover {
            background-color: #f9f9f9;
          }
          .todo .checkbox {
            display: inline-block;
            width: 32px;
            text-align: center;
            font-family: monospace;
            font-size: 16px;
            font-weight: bold;
            color: #4a90d9;
            flex-shrink: 0;
          }
          .todo.completed {
            text-decoration: line-through;
            color: #999;
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
          .filters-container h1 {
            font-size: 28px;
            margin-bottom: 20px;
            color: #333;
          }
          .filter-bar {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
          }
          .filter-btn {
            padding: 8px 16px;
            border: 2px solid #4a90d9;
            border-radius: 4px;
            background: white;
            color: #4a90d9;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.2s;
          }
          .filter-btn:hover {
            background: #f0f8ff;
          }
          .filter-btn.active {
            background: #4a90d9;
            color: white;
          }
          .search-bar {
            margin-bottom: 20px;
          }
          .search-input {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 4px;
            font-size: 16px;
            box-sizing: border-box;
          }
          .search-input:focus {
            outline: none;
            border-color: #4a90d9;
          }
          .stats-bar {
            display: flex;
            gap: 20px;
            padding: 12px;
            background: #f8f9fa;
            border-radius: 4px;
            margin-bottom: 20px;
          }
          .stat {
            font-weight: bold;
            color: #555;
          }
          .status-bar {
            margin-top: 20px;
            padding: 12px;
            background: #fff3cd;
            border-radius: 4px;
            color: #856404;
            font-weight: bold;
          }
          .inline-edit-container h1 {
            font-size: 28px;
            margin-bottom: 20px;
            color: #333;
          }
          .instructions {
            font-style: italic;
            color: #666;
            margin-bottom: 20px;
          }
          .todo-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            border-bottom: 1px solid #eee;
            user-select: none;
          }
          .todo-item.editing {
            background: #f0f8ff;
            border-left: 4px solid #4a90d9;
          }
          .btn-edit {
            margin-left: auto;
            padding: 6px 12px;
            border: 1px solid #4a90d9;
            border-radius: 4px;
            background: white;
            color: #4a90d9;
            cursor: pointer;
            font-size: 14px;
          }
          .btn-edit:hover {
            background: #f0f8ff;
          }
          .edit-input {
            flex: 1;
            padding: 8px;
            border: 2px solid #4a90d9;
            border-radius: 4px;
            font-size: 16px;
          }
          .edit-input:focus {
            outline: none;
            border-color: #357abd;
            box-shadow: 0 0 0 3px rgba(74, 144, 217, 0.1);
          }
          .btn-save {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #28a745;
            color: white;
            cursor: pointer;
            font-weight: bold;
          }
          .btn-save:hover {
            background: #218838;
          }
          .btn-cancel {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #dc3545;
            color: white;
            cursor: pointer;
            font-weight: bold;
          }
          .btn-cancel:hover {
            background: #c82333;
          }
          .todo-text.saving {
            color: #999;
            font-style: italic;
          }
        </style>|};
      ] ();
      body ~children:[
        (* Import map for Melange runtime and local modules - must come before module scripts *)
        raw {|<script type="importmap">
{
  "imports": {
    "melange.js/": "/static/melange.js/",
    "melange/": "/static/node_modules/melange/",
    "melange.__private__/": "/static/node_modules/melange.__private__/",
    "full_ssr_app/": "/static/examples/full_ssr_app/",
    "full_ssr_app.__private__/": "/static/node_modules/full_ssr_app.__private__/",
    "full_ssr_app.__private__.shared_components/": "/static/node_modules/full_ssr_app.__private__.shared_components/",
    "solid-ml-browser/": "/static/node_modules/solid-ml-browser/",
    "solid-ml/": "/static/node_modules/solid-ml/",
    "solid-ml-internal/": "/static/node_modules/solid-ml-internal/",
    "solid-ml-template-runtime/": "/static/node_modules/solid-ml-template-runtime/"
  }
}
</script>|};
        (* App root for true hydration *)
        Html.div ~id:"app" ~children:children_list ();

        (* Initial state for hydration *)
        raw (Render.get_hydration_script ());

        (* Hydration script *)
        script ~src:"/static/client.js" ~type_:"module" ~children:[] ();
      ] ()
    ] ()
  )

(** Home page *)
let home_page ~current_path () =
  layout ~title:"Home - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.home_page ()
    ) ()
  ) ()

(** Counter page - uses Shared.counter *)
let counter_page ~current_path ~initial () =
  layout ~title:"Counter - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.counter_content ~initial ()
    ) ()
  ) ()

(** Todos page - uses Shared.todo_list *)
let todos_page ~current_path ~todos () =
  layout ~title:"Todos - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Shared.todos_content ~initial_todos:todos ()
    ) ()
  ) ()

(** Filters page - uses Filters.view *)
let filters_page ~current_path ~todos () =
  layout ~title:"Filters - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Filters.view ~initial_todos:todos ()
    ) ()
  ) ()

(** 404 page *)
let not_found_page ~current_path ~request_path () =
  layout ~title:"Not Found - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Html.div ~children:[
        Html.h2 ~children:[Html.text "404 - Page Not Found"] ();
        Html.p ~children:[
          Html.text ("The page " ^ request_path ^ " was not found.");
        ] ();
      ] ()
    ) ()
  ) ()

(** {1 Request Handlers} *)

let handle_home req =
  let html = Render.to_document (fun () ->
    home_page ~current_path:(Dream.target req) ())
  in
  Dream.html html

let handle_keyed _req =
  let html =
    Render.to_document (fun () ->
      layout ~title:"Keyed - solid-ml SSR" ~children:(
        Shared.app_layout ~current_path:(Routes.path Routes.Keyed) ~children:(
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
        Shared.app_layout ~current_path:(Routes.path Routes.Template_keyed) ~children:(
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
  let counter_key = State.key ~namespace:"full_ssr" "counter" in
  let html = Render.to_document (fun () ->
    State.set_encoded ~key:counter_key ~encode:State.encode_int initial;
    counter_page ~current_path:(Routes.path Routes.Counter) ~initial ())
  in
  Dream.html html

let handle_todos _req =
  let todos_key = State.key ~namespace:"full_ssr" "todos" in
  let html = Render.to_document (fun () ->
    let encode_todo (todo : Shared_components.Components.todo) =
      State.encode_object [
        ("id", State.encode_int todo.id);
        ("text", State.encode_string todo.text);
        ("completed", State.encode_bool todo.completed);
      ]
    in
    State.set_encoded
      ~key:todos_key
      ~encode:State.encode_list
      (List.map encode_todo sample_todos);
    todos_page ~current_path:(Routes.path Routes.Todos) ~todos:sample_todos ())
  in
  Dream.html html

let handle_filters _req =
  let html = Render.to_document (fun () ->
    filters_page ~current_path:(Routes.path Routes.Filters) ~todos:sample_todos_filters ())
  in
  Dream.html html

(** Inline-edit page - uses Inline_edit.view *)
let inline_edit_page ~current_path ~todos () =
  layout ~title:"Inline Edit - solid-ml SSR" ~children:(
    Shared.app_layout ~current_path ~children:(
      Inline_edit.view ~initial_todos:todos ()
    ) ()
  ) ()

let handle_inline_edit _req =
  let html = Render.to_document (fun () ->
    inline_edit_page ~current_path:(Routes.path Routes.Inline_edit) ~todos:sample_todos_inline_edit ())
  in
  Dream.html html

let handle_not_found req =
  let path = Dream.target req in
  let html = Render.to_document (fun () ->
    not_found_page ~current_path:path ~request_path:path ())
  in
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
  Printf.printf "  http://localhost:%d/             - Home\n" port;
  Printf.printf "  http://localhost:%d/counter      - Counter\n" port;
  Printf.printf "  http://localhost:%d/todos        - Todos\n" port;
  Printf.printf "  http://localhost:%d/filters      - Filters\n" port;
  Printf.printf "  http://localhost:%d/inline-edit  - Inline-Edit\n" port;
  Printf.printf "\n";
  Printf.printf "Build client with: make example-full-ssr-client\n";
  Printf.printf "Press Ctrl+C to stop\n";
  flush stdout;

  Dream.run ~port ~interface:"0.0.0.0"
  @@ Dream.logger
  @@ Dream.router [
    Dream.get "/" handle_home;
    Dream.get "/counter" handle_counter;
    Dream.get "/todos" handle_todos;
    Dream.get "/filters" handle_filters;
    Dream.get "/inline-edit" handle_inline_edit;
    Dream.get "/keyed" handle_keyed;
    Dream.get "/template-keyed" handle_template_keyed;
    Dream.get "/static/**" (Dream.static "examples/full_ssr_app/static");
    Dream.any "/**" handle_not_found;
  ]

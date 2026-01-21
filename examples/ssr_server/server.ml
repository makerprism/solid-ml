(** Dream server example demonstrating solid-ml SSR.

    This example shows:
    - Server-side rendering with Dream
    - Thread-safe rendering (each request gets its own runtime)
    - Building HTML components with solid-ml-html
    - Reactive signals for server-rendered content

    To run this example:
    1. Add 'dream' to your opam dependencies: opam install dream
    2. Run: dune exec examples/ssr_server/server.exe
    3. Visit http://localhost:8080

    NOTE: This example requires the 'dream' package to be installed.
    If it's not available, this file serves as documentation of the pattern.
*)

open Solid_ml_ssr

module C = Ssr_server_shared.Components.App (Solid_ml_ssr.Env)

(** Page layout component *)
let layout ~title:page_title ~children () =
  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        (* Inline CSS for demo *)
        Html.raw {|<style>
          body { font-family: system-ui, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
          .counter { padding: 20px; background: #f0f0f0; border-radius: 8px; }
          .count { font-size: 48px; font-weight: bold; color: #333; }
          nav { margin-bottom: 20px; }
          nav a { margin-right: 15px; color: #0066cc; }
          .todo-item { padding: 8px; border-bottom: 1px solid #eee; }
          .todo-item.completed { text-decoration: line-through; color: #999; }
        </style>|};
      ] ();
      body ~children ()
    ] ()
  )

(** Dream request handlers *)

let handle_home _req =
  let html = Render.to_document (fun () ->
    layout ~title:"solid-ml SSR Demo" ~children:[
      C.app ~page:C.Home ()
    ] ())
  Dream.html html

let handle_counter req =
  (* Get initial count from query parameter, default to 0 *)
  let initial = 
    Dream.query req "count"
    |> Option.map int_of_string_opt
    |> Option.join
    |> Option.value ~default:0
  in
  let html = Render.to_document (fun () ->
    layout ~title:"Counter - solid-ml" ~children:[
      C.app ~page:(C.Counter initial) ()
    ] ())
  Dream.html html

let handle_todos _req =
  let html = Render.to_document (fun () ->
    layout ~title:"Todos - solid-ml" ~children:[
      C.app ~page:(C.Todos Ssr_server_shared.sample_todos) ()
    ] ())
  Dream.html html

(** Main server *)
let () =
  (* Allow port to be configured via environment variable *)
  let port = 
    match Sys.getenv_opt "PORT" with
    | Some p -> (try int_of_string p with _ -> 8080)
    | None -> 8080
  in
  Printf.printf "Starting solid-ml SSR server on http://localhost:%d\n" port;
  print_endline "Try these URLs:";
  Printf.printf "  http://localhost:%d/\n" port;
  Printf.printf "  http://localhost:%d/counter?count=42\n" port;
  Printf.printf "  http://localhost:%d/todos\n" port;
  print_endline "";
  print_endline "Set PORT environment variable to use a different port.";
  flush stdout;
  Dream.run ~port
  @@ Dream.logger
  @@ Dream.router [
    Dream.get "/" handle_home;
    Dream.get "/counter" handle_counter;
    Dream.get "/todos" handle_todos;
  ]

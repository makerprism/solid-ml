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

open Solid_ml
open Solid_ml_ssr

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

(** Navigation component *)
let navigation () =
  Html.(
    nav ~children:[
      a ~href:"/" ~children:[text "Home"] ();
      a ~href:"/counter" ~children:[text "Counter"] ();
      a ~href:"/todos" ~children:[text "Todos"] ();
    ] ()
  )

(** Home page component *)
let home_page () =
  layout ~title:"solid-ml SSR Demo" ~children:[
    navigation ();
    Html.(
      fragment [
        h1 ~children:[text "solid-ml SSR Demo"] ();
        p ~children:[text "This is a server-side rendered page using solid-ml-html."] ();
        p ~children:[
          text "Each page request creates an isolated runtime, making it safe for concurrent requests."
        ] ();
        h2 ~children:[text "Features Demonstrated"] ();
        ul ~children:[
          li ~children:[text "Server-side HTML rendering"] ();
          li ~children:[text "Thread-safe runtime isolation"] ();
          li ~children:[text "Reactive signals (server-evaluated)"] ();
          li ~children:[text "Component composition"] ();
        ] ();
      ]
    )
  ] ()

(** Counter page - demonstrates signals in SSR *)
let counter_page ~initial () =
  (* Create a signal - on server, we just read the initial value *)
  let count, _set_count = Signal.create initial in
  let doubled = Memo.create (fun () -> Signal.get count * 2) in
  
  layout ~title:"Counter - solid-ml" ~children:[
    navigation ();
    Html.(
      div ~class_:"counter" ~children:[
        h1 ~children:[text "Server-Rendered Counter"] ();
        p ~children:[text "Initial count from URL parameter:"] ();
        div ~class_:"count" ~children:[
          (* Use signal_text for hydration markers *)
          signal_text count
        ] ();
        p ~children:[
          text "Doubled: ";
          (* For SSR, we read the memo value directly *)
          text (string_of_int (Memo.get doubled));
        ] ();
        p ~children:[
          em ~children:[
            text "(In a full app, this would become interactive after hydration)"
          ] ()
        ] ();
      ] ()
    )
  ] ()

(** Todo type *)
type todo = {
  id : int;  (* Used for keying in a real app *)
  text : string;
  completed : bool;
} [@@warning "-69"]

(** Todos page - demonstrates list rendering *)
let todos_page ~todos () =
  let incomplete = List.filter (fun t -> not t.completed) todos in
  let count_signal, _ = Signal.create (List.length incomplete) in
  
  layout ~title:"Todos - solid-ml" ~children:[
    navigation ();
    Html.(
      fragment [
        h1 ~children:[text "Server-Rendered Todos"] ();
        p ~children:[
          signal_text count_signal;
          text " items remaining";
        ] ();
        div ~children:(
          List.map (fun todo ->
            div ~class_:(if todo.completed then "todo-item completed" else "todo-item")
              ~children:[
                input ~type_:"checkbox" ~checked:todo.completed ();
                span ~children:[text (" " ^ todo.text)] ();
              ] ()
          ) todos
        ) ()
      ]
    )
  ] ()

(** Sample todos for demo *)
let sample_todos = [
  { id = 1; text = "Learn OCaml"; completed = true };
  { id = 2; text = "Build solid-ml app"; completed = false };
  { id = 3; text = "Add client-side hydration"; completed = false };
  { id = 4; text = "Deploy to production"; completed = false };
]

(** Dream request handlers *)

let handle_home _req =
  let html = Render.to_document home_page in
  Dream.html html

let handle_counter req =
  (* Get initial count from query parameter, default to 0 *)
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

(** Router example demonstrating solid-ml-router.
    
    This example shows:
    - Route definition with patterns, params, and wildcards
    - Server-side route matching and rendering
    - NavLink with active class
    - Outlet for rendering matched routes
    - URL parsing and query string handling
    
    To run this example:
      dune exec examples/router/router.exe
*)

open Solid_ml_html
open Solid_ml_router

(** {1 Page Components} *)

(** Home page *)
let home_page () =
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Home"] ();
      p ~children:[text "Welcome to the solid-ml router example!"] ();
      p ~children:[text "Use the navigation above to explore different routes."] ();
    ] ()
  )

(** Users list page *)
let users_page () =
  let users = ["alice"; "bob"; "charlie"] in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Users"] ();
      ul ~children:(
        List.map (fun user ->
          li ~children:[
            Components.link ~href:("/users/" ^ user) ~children:[
              text user
            ] ()
          ] ()
        ) users
      ) ()
    ] ()
  )

(** User profile page - uses route params *)
let user_profile_page () =
  let username = Router.use_param "username" |> Option.value ~default:"unknown" in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text ("User: " ^ username)] ();
      p ~children:[text ("This is " ^ username ^ "'s profile page.")] ();
      p ~children:[
        Components.link ~href:"/users" ~children:[text "Back to users list"] ()
      ] ();
    ] ()
  )

(** About page *)
let about_page () =
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "About"] ();
      p ~children:[text "solid-ml is an OCaml framework for reactive web applications."] ();
      h3 ~children:[text "Features"] ();
      ul ~children:[
        li ~children:[text "Fine-grained reactivity (no virtual DOM)"] ();
        li ~children:[text "Server-side rendering with hydration markers"] ();
        li ~children:[text "Type-safe routing with params and wildcards"] ();
        li ~children:[text "Shared reactive core between server and browser"] ();
      ] ()
    ] ()
  )

(** Docs page with wildcard path *)
let docs_page () =
  (* The "*" param captures everything after /docs/ *)
  let doc_path = 
    match Router.use_param "*" with
    | Some p when p <> "" -> p
    | _ -> "index"
  in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Documentation"] ();
      p ~children:[text ("You're viewing: " ^ doc_path)] ();
      h3 ~children:[text "Available Docs"] ();
      ul ~children:[
        li ~children:[
          Components.link ~href:"/docs/getting-started" ~children:[
            text "Getting Started"
          ] ()
        ] ();
        li ~children:[
          Components.link ~href:"/docs/signals" ~children:[
            text "Signals"
          ] ()
        ] ();
        li ~children:[
          Components.link ~href:"/docs/router/basics" ~children:[
            text "Router Basics"
          ] ()
        ] ();
      ] ()
    ] ()
  )

(** 404 page *)
let not_found_page () =
  Html.(
    div ~class_:"page error" ~children:[
      h2 ~children:[text "404 - Not Found"] ();
      p ~children:[text "The page you're looking for doesn't exist."] ();
      p ~children:[
        Components.link ~href:"/" ~children:[text "Go home"] ()
      ] ()
    ] ()
  )

(** {1 Route Definitions} *)

(** Define routes with their patterns and associated components *)
let routes : (unit -> Html.node) Route.t list = [
  Route.create ~path:"/" ~data:home_page;
  Route.create ~path:"/users" ~data:users_page;
  Route.create ~path:"/users/:username" ~data:user_profile_page;
  Route.create ~path:"/about" ~data:about_page;
  Route.create ~path:"/docs/*" ~data:docs_page;
]

(** {1 Layout} *)

(** Navigation bar using NavLink for active styling *)
let nav_bar () =
  Html.(
    nav ~class_:"nav" ~children:[
      Components.nav_link ~href:"/" ~exact:true ~children:[text "Home"] ();
      Components.nav_link ~href:"/users" ~children:[text "Users"] ();
      Components.nav_link ~href:"/about" ~children:[text "About"] ();
      Components.nav_link ~href:"/docs" ~children:[text "Docs"] ();
    ] ()
  )

(** Main layout wrapping all pages *)
let layout ~children () =
  Html.(
    div ~class_:"app" ~children:[
      h1 ~children:[text "solid-ml Router Example"] ();
      nav_bar ();
      div ~class_:"content" ~children ()
    ] ()
  )

(** {1 Rendering} *)

(** Render the app for a given path *)
let render_app path =
  (* Provide router context, then render layout with outlet *)
  Components.provide ~initial_path:path ~routes (fun () ->
    layout ~children:[
      Components.outlet ~routes ~not_found:not_found_page ()
    ] ()
  )

(** {1 Demo} *)

let () =
  print_endline "=== Router Example ===\n";
  
  (* Test different routes *)
  let test_paths = [
    "/";
    "/users";
    "/users/alice";
    "/about";
    "/docs";
    "/docs/getting-started";
    "/docs/router/basics";
    "/unknown-page";
    "/users/bob?tab=posts#section2";
  ] in
  
  List.iter (fun path ->
    print_endline ("--- Path: " ^ path ^ " ---");
    let html = Render.to_string (fun () -> render_app path) in
    print_endline html;
    print_newline ()
  ) test_paths;
  
  print_endline "=== URL Parsing Examples ===\n";
  
  let test_urls = [
    "/search?q=ocaml&page=2";
    "/profile#settings";
    "/users/alice?tab=posts#bio";
  ] in
  
  List.iter (fun url ->
    let path, query, hash = Router.parse_url url in
    Printf.printf "URL: %s\n" url;
    Printf.printf "  Path: %s\n" path;
    Printf.printf "  Query: %s\n" (Option.value ~default:"(none)" query);
    Printf.printf "  Hash: %s\n" (Option.value ~default:"(none)" hash);
    
    (* If there's a query string, parse its params *)
    (match query with
    | Some q ->
      let params = Router.parse_query_string q in
      print_endline "  Query params:";
      List.iter (fun (k, v) -> Printf.printf "    %s = %s\n" k v) params
    | None -> ());
    print_newline ()
  ) test_urls;
  
  print_endline "=== Route Matching Examples ===\n";
  
  let match_examples = [
    "/";
    "/users";
    "/users/charlie";
    "/docs/intro";
    "/docs/api/signals";
    "/not-a-route";
  ] in
  
  List.iter (fun path ->
    match Route.match_routes routes path with
    | Some (route, result) ->
      Printf.printf "Path '%s' -> matched pattern '%s'\n" path (Route.path_template route);
      if not (Route.Params.is_empty result.params) then begin
        print_endline "  Params:";
        Route.Params.iter (fun k v -> Printf.printf "    %s = %s\n" k v) result.params
      end
    | None ->
      Printf.printf "Path '%s' -> no match (404)\n" path
  ) match_examples;
  
  print_endline "\n=== Router example completed! ==="

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

 open Solid_ml_ssr
 open Solid_ml_router

 (** {1 Common Helper Patterns} *)

 (** Result type for safe parameter extraction *)
type ('a, 'e) result =
  | Ok of 'a
  | Error of 'e

let use_param_safe param_name =
  match Router.use_param param_name with
  | Some v -> Ok v
  | None -> Error ("Missing parameter: " ^ param_name)

 (** {1 Data Loading Pattern}

   Shows how to handle data loading with error states.
   In a real app, this would fetch from a database or API. *)

type user = {
  id : string;
  name : string;
  email : string;
}

let fake_users = [
  ("alice", { id = "alice"; name = "Alice Johnson"; email = "alice@example.com" });
  ("bob", { id = "bob"; name = "Bob Smith"; email = "bob@example.com" });
  ("charlie", { id = "charlie"; name = "Charlie Brown"; email = "charlie@example.com" });
]

let fetch_user username =
  try
    let user = List.assoc username fake_users in
    Ok user
  with Not_found ->
    Error ("User not found: " ^ username)

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

(** User profile page - uses route params with error handling *)
let user_profile_page () =
  match use_param_safe "username" with
  | Error msg ->
    Html.(
      div ~class_:"page error" ~children:[
        h2 ~children:[text "Error"] ();
        p ~children:[text msg] ();
        p ~children:[
          Components.link ~href:"/users" ~children:[text "Back to users list"] ()
        ] ()
      ] ()
    )
  | Ok username ->
    match fetch_user username with
    | Error err ->
      Html.(
        div ~class_:"page error" ~children:[
          h2 ~children:[text "User Not Found"] ();
          p ~children:[text err] ();
          p ~children:[
            Components.link ~href:"/users" ~children:[text "Back to users list"] ()
          ] ()
        ] ()
      )
    | Ok user ->
      Html.(
        div ~class_:"page" ~children:[
          h2 ~children:[text user.name] ();
          p ~children:[text ("ID: " ^ user.id)] ();
          p ~children:[text ("Email: " ^ user.email)] ();
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

 (** Protected route example - shows authentication guard pattern *)
let admin_page () =
  (* In a real app, check authentication state *)
  (* This demonstrates the pattern of redirecting unauthenticated users *)
  let is_authenticated = false in

  if not is_authenticated then
    Html.(
      div ~class_:"page error" ~children:[
        h2 ~children:[text "Authentication Required"] ();
        p ~children:[text "You must be logged in to access the admin panel."] ();
        p ~children:[
          Components.link ~href:"/login" ~children:[text "Go to login"] ()
        ] ();
      ] ()
    )
  else
    Html.(
      div ~class_:"page" ~children:[
        h2 ~children:[text "Admin Panel"] ();
        p ~children:[text "Welcome, administrator!"] ();
        ul ~children:[
          li ~children:[text "User Management"] ();
          li ~children:[text "System Settings"] ();
          li ~children:[text "Logs and Monitoring"] ();
        ] ();
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
  Route.create ~path:"/admin" ~data:admin_page;
]

(** {1 Layout} *)

(** Navigation bar using NavLink for active styling *)
let nav_bar () =
  Html.(
    nav ~class_:"nav" ~children:[
      Components.nav_link ~href:"/" ~exact:true ~children:[text "Home"] ();
      Components.nav_link ~href:"/users" ~children:[text "Users"] ();
      Components.nav_link ~href:"/admin" ~children:[text "Admin"] ();
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
    "/admin";
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

  print_endline "\n=== Router Patterns ===\n";
  print_endline "Protected Routes:";
  print_endline "  Check authentication state in the page component";
  print_endline "  Redirect to login if not authenticated";
  print_endline "";
  print_endline "Data Loading:";
  print_endline "  Use Result type for safe parameter extraction";
  print_endline "  Match on Result to handle errors gracefully";
  print_endline "  Show different views for Loading/Error/Success states";
  print_endline "";
  print_endline "Route Types:";
  print_endline "  Static: '/about' - exact match";
  print_endline "  Param: '/users/:id' - extracts parameter";
  print_endline "  Wildcard: '/docs/*' - captures everything after /docs/";

  print_endline "\n=== Router example completed! ==="

(** Interactive router example for the browser.
    
    This example demonstrates:
    - Client-side routing with solid-ml-browser Router
    - Navigation without page reloads
    - Dynamic route parameters
    - NavLink with active styling
    - Nested routes and wildcards
    
    Build with: make example-browser-router
    Then open examples/browser_router/index.html in a browser.
*)

open Solid_ml_browser
open Reactive

(** {1 Page Components} *)

(** Home page *)
let home_page () =
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Home"] ();
      p ~children:[text "Welcome to the solid-ml browser router demo!"] ();
      p ~children:[text "Click the navigation links above to see client-side routing in action."] ();
      p ~children:[text "Notice how the page doesn't reload - only the content changes."] ();
    ] ()
  )

(** Counter page - demonstrates state within routed pages *)
let counter_page () =
  let count, set_count = Signal.create 0 in
  let doubled = Memo.create (fun () -> Signal.get count * 2) in
  
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Counter"] ();
      p ~children:[text "This counter demonstrates reactive state within a routed page."] ();
      
      div ~class_:"counter-display" ~children:[
        p ~children:[
          text "Count: ";
          Reactive.text count;
        ] ();
        p ~children:[
          text "Doubled: ";
          Reactive.memo_text doubled;
        ] ();
      ] ();
      
      div ~class_:"buttons" ~children:[
        button ~class_:"btn" ~onclick:(fun _ -> 
          Signal.update count (fun n -> n - 1)
        ) ~children:[text "-"] ();
        button ~class_:"btn" ~onclick:(fun _ -> 
          Signal.update count (fun n -> n + 1)
        ) ~children:[text "+"] ();
        button ~class_:"btn btn-secondary" ~onclick:(fun _ -> set_count 0) 
          ~children:[text "Reset"] ();
      ] ();
    ] ()
  )

(** Users list page *)
let users_page () =
  let users = ["alice"; "bob"; "charlie"; "diana"] in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Users"] ();
      p ~children:[text "Click a user to see their profile (dynamic route param)."] ();
      ul ~class_:"user-list" ~children:(
        List.map (fun user ->
          li ~children:[
            Router.link ~href:("/users/" ^ user) ~children:[
              text user
            ] ()
          ] ()
        ) users
      ) ()
    ] ()
  )

(** User profile page - demonstrates route params *)
let user_profile_page () =
  let username = Router.use_param "username" |> Option.value ~default:"unknown" in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text ("User: " ^ username)] ();
      p ~children:[text ("Welcome to " ^ username ^ "'s profile page!")] ();
      p ~children:[text "This page was rendered using the :username route parameter."] ();
      p ~children:[
        Router.link ~href:"/users" ~children:[text "Back to users list"] ()
      ] ();
    ] ()
  )

(** About page *)
let about_page () =
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "About"] ();
      p ~children:[text "solid-ml is an OCaml framework for reactive web applications."] ();
      
      h3 ~children:[text "Key Features"] ();
      ul ~children:[
        li ~children:[text "Fine-grained reactivity (no virtual DOM)"] ();
        li ~children:[text "Server-side rendering with hydration"] ();
        li ~children:[text "Type-safe routing with params and wildcards"] ();
        li ~children:[text "Shared reactive core between server and browser"] ();
      ] ();
      
      h3 ~children:[text "Router Features"] ();
      ul ~children:[
        li ~children:[text "Client-side navigation (no page reloads)"] ();
        li ~children:[text "History API integration (back/forward work)"] ();
        li ~children:[text "Dynamic route parameters (:param)"] ();
        li ~children:[text "Wildcard routes (*)"] ();
        li ~children:[text "NavLink with active class styling"] ();
      ] ();
    ] ()
  )

(** Docs page with wildcard path *)
let docs_page () =
  let doc_path = 
    match Router.use_param "*" with
    | Some p when p <> "" -> p
    | _ -> "index"
  in
  Html.(
    div ~class_:"page" ~children:[
      h2 ~children:[text "Documentation"] ();
      p ~children:[
        text "Current doc: ";
        strong ~children:[text doc_path] ();
      ] ();
      p ~children:[text "This page uses a wildcard route to capture any path after /docs/"] ();
      
      h3 ~children:[text "Available Docs"] ();
      ul ~children:[
        li ~children:[
          Router.link ~href:"/docs/getting-started" ~children:[text "Getting Started"] ()
        ] ();
        li ~children:[
          Router.link ~href:"/docs/signals" ~children:[text "Signals"] ()
        ] ();
        li ~children:[
          Router.link ~href:"/docs/effects" ~children:[text "Effects"] ()
        ] ();
        li ~children:[
          Router.link ~href:"/docs/router/basics" ~children:[text "Router Basics"] ()
        ] ();
        li ~children:[
          Router.link ~href:"/docs/router/params" ~children:[text "Router Params"] ()
        ] ();
      ] ()
    ] ()
  )

(** 404 page *)
let not_found_page () =
  Html.(
    div ~class_:"page error-page" ~children:[
      h2 ~children:[text "404 - Not Found"] ();
      p ~children:[text "The page you're looking for doesn't exist."] ();
      p ~children:[
        Router.link ~href:"/" ~children:[text "Go home"] ()
      ] ()
    ] ()
  )

(** {1 Route Definitions} *)

(** Routes with their component render functions *)
let routes : (unit -> Html.node) Router.Route.t list = [
  Router.Route.create ~path:"/" ~data:home_page ();
  Router.Route.create ~path:"/counter" ~data:counter_page ();
  Router.Route.create ~path:"/users" ~data:users_page ();
  Router.Route.create ~path:"/users/:username" ~data:user_profile_page ();
  Router.Route.create ~path:"/about" ~data:about_page ();
  Router.Route.create ~path:"/docs/*" ~data:docs_page ();
]

(** Routes for config (just patterns, no data needed) *)
let config_routes : unit Router.Route.t list = [
  Router.Route.create ~path:"/" ~data:() ();
  Router.Route.create ~path:"/counter" ~data:() ();
  Router.Route.create ~path:"/users" ~data:() ();
  Router.Route.create ~path:"/users/:username" ~data:() ();
  Router.Route.create ~path:"/about" ~data:() ();
  Router.Route.create ~path:"/docs/*" ~data:() ();
]

(** {1 Layout} *)

(** Navigation bar using NavLink for active styling *)
let nav_bar () =
  Html.(
    nav ~class_:"nav" ~children:[
      Router.nav_link ~href:"/" ~exact:true ~children:[text "Home"] ();
      Router.nav_link ~href:"/counter" ~children:[text "Counter"] ();
      Router.nav_link ~href:"/users" ~children:[text "Users"] ();
      Router.nav_link ~href:"/docs" ~children:[text "Docs"] ();
      Router.nav_link ~href:"/about" ~children:[text "About"] ();
    ] ()
  )

(** Main app layout *)
let app () =
  Html.(
    div ~class_:"app" ~children:[
      header ~children:[
        h1 ~children:[text "solid-ml Router Demo"] ();
        nav_bar ();
      ] ();
      main ~children:[
        Router.outlet ~routes ~not_found:not_found_page ()
      ] ();
      footer ~children:[
        p ~children:[
          text "Built with ";
          a ~href:"https://github.com/makerprism/solid-ml" ~target:"_blank" 
            ~children:[text "solid-ml"] ();
        ] ()
      ] ();
    ] ()
  )

(** {1 Main Entry Point} *)

let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some root ->
    (* Set base to /browser_router since we're served from that subdirectory *)
    let config = Router.{ 
      routes = config_routes; 
      base = "/browser_router";
      scroll_restoration = true 
    } in
    let (_result, _dispose) = Router.init ~config (fun () ->
      let _render_dispose = Render.render root (fun () -> app ()) in
      ()
    ) in
    Dom.log "solid-ml router demo initialized!"
  | None ->
    Dom.error "Could not find #app element"


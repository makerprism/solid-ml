module type HTML = sig
  type node

  val text : string -> node
  val div : ?id:string -> ?class_:string -> ?style:string -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val header : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val nav : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val main : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val footer : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val h1 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val h2 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val h3 : ?id:string -> ?class_:string -> ?tabindex:int -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val p : ?id:string -> ?class_:string -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val ul : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val li : ?id:string -> ?class_:string -> ?role:string -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val strong : ?id:string -> ?class_:string -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val fragment : node list -> node
end

module type BASE = sig
  val base : string
end

module Make (Html : HTML) (Router : sig
  module Route : sig
    type 'a t
    val create : path:string -> data:'a -> unit -> 'a t
  end
  val link : ?class_:string -> href:string -> children:Html.node list -> unit -> Html.node
  val nav_link : ?class_:string -> ?active_class:string -> ?exact:bool -> href:string -> children:Html.node list -> unit -> Html.node
  val outlet : routes:(unit -> Html.node) Route.t list -> ?not_found:(unit -> Html.node) -> unit -> Html.node
  val use_param : string -> string option
end) (Base : BASE) = struct
  open Html

  let href path = Base.base ^ path

  let home_page () =
    div ~class_:"page" ~children:[
      h2 ~children:[text "Home"] ();
      p ~children:[text "Welcome to the solid-ml router demo!"] ();
      p ~children:[text "Click the navigation links above to see routing in action."] ();
      p ~children:[text "This example supports SSR + client-side navigation."] ();
    ] ()

  let counter_page () =
    div ~class_:"page" ~children:[
      h2 ~children:[text "Counter"] ();
      p ~children:[text "This counter demonstrates reactive state within a routed page."] ();
      div ~class_:"counter-display" ~children:[
        p ~children:[text "Count: "; text "0"] ();
        p ~children:[text "Doubled: "; text "0"] ();
      ] ();
    ] ()

  let users_page () =
    let users = ["alice"; "bob"; "charlie"; "diana"] in
    div ~class_:"page" ~children:[
      h2 ~children:[text "Users"] ();
      p ~children:[text "Click a user to see their profile (dynamic route param)."] ();
      ul ~class_:"user-list" ~children:(
        List.map (fun user ->
          li ~children:[
            Router.link ~href:(href ("/users/" ^ user)) ~children:[text user] ()
          ] ()
        ) users
      ) ()
    ] ()

  let user_profile_page () =
    let username = Router.use_param "username" |> Option.value ~default:"unknown" in
    div ~class_:"page" ~children:[
      h2 ~children:[text ("User: " ^ username)] ();
      p ~children:[text ("Welcome to " ^ username ^ "'s profile page!")] ();
      p ~children:[text "This page was rendered using the :username route parameter."] ();
      p ~children:[
        Router.link ~href:(href "/users") ~children:[text "Back to users list"] ()
      ] ();
    ] ()

  let about_page () =
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

  let docs_page () =
    let doc_path =
      match Router.use_param "*" with
      | Some p when p <> "" -> p
      | _ -> "index"
    in
    div ~class_:"page" ~children:[
      h2 ~children:[text "Documentation"] ();
      p ~children:[text "Current doc: "; strong ~children:[text doc_path] ()] ();
      p ~children:[text "This page uses a wildcard route to capture any path after /docs/."] ();
      h3 ~children:[text "Available Docs"] ();
      ul ~children:[
        li ~children:[Router.link ~href:(href "/docs/getting-started") ~children:[text "Getting Started"] ()] ();
        li ~children:[Router.link ~href:(href "/docs/signals") ~children:[text "Signals"] ()] ();
        li ~children:[Router.link ~href:(href "/docs/effects") ~children:[text "Effects"] ()] ();
        li ~children:[Router.link ~href:(href "/docs/router/basics") ~children:[text "Router Basics"] ()] ();
        li ~children:[Router.link ~href:(href "/docs/router/params") ~children:[text "Router Params"] ()] ();
      ] ()
    ] ()

  let not_found_page () =
    div ~class_:"page error-page" ~children:[
      h2 ~children:[text "404 - Not Found"] ();
      p ~children:[text "The page you're looking for doesn't exist."] ();
      p ~children:[Router.link ~href:(href "/") ~children:[text "Go home"] ()] ();
    ] ()

  let route_specs : (string * (unit -> Html.node)) list = [
    ("/", home_page);
    ("/counter", counter_page);
    ("/users", users_page);
    ("/users/:username", user_profile_page);
    ("/about", about_page);
    ("/docs/*", docs_page);
  ]

  let routes : (unit -> Html.node) Router.Route.t list =
    List.map (fun (path, data) -> Router.Route.create ~path ~data ()) route_specs

  let config_routes : unit Router.Route.t list =
    List.map (fun (path, _data) -> Router.Route.create ~path ~data:() ()) route_specs

  let nav_bar () =
    nav ~class_:"nav" ~children:[
      Router.nav_link ~href:(href "/") ~exact:true ~children:[text "Home"] ();
      Router.nav_link ~href:(href "/counter") ~children:[text "Counter"] ();
      Router.nav_link ~href:(href "/users") ~children:[text "Users"] ();
      Router.nav_link ~href:(href "/docs") ~children:[text "Docs"] ();
      Router.nav_link ~href:(href "/about") ~children:[text "About"] ();
    ] ()

  let app () =
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
          Html.a ~href:"https://github.com/makerprism/solid-ml" ~target:"_blank" ~children:[text "solid-ml"] ()
        ] ()
      ] ();
    ] ()
end
  val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> ?rel:string -> ?download:string -> ?hreflang:string -> ?tabindex:int -> ?onclick:(unit -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node

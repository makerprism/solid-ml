(** Router components for server-side rendering.
    
    These components render to HTML on the server. The browser-side
    implementation will enhance them with client-side navigation.
*)

open Solid_ml

(** {1 Router Provider} *)

(** Initialize the router with the given path and routes.
    
    This sets up the router context with:
    - The initial navigation state based on the current path
    - Route matching to extract params
    
    On the server, the initial_path should be the request URL.
    On the browser, it should be window.location.pathname + search + hash.
    
    @param initial_path The current URL path (with optional query and hash)
    @param routes Routes used for param extraction (can be empty if not needed)
    @param f Function to run with the router context *)
let provide ~initial_path ?(routes=[]) f =
  let path, query, hash = Router.parse_url initial_path in
  
  (* Match against routes to get params *)
  let params = 
    match Router.match_path routes path with
    | Some (_, result) -> result.params
    | None -> Route.Params.empty
  in
  
  let initial_state : Router.nav_state = {
    path;
    params;
    query;
    hash;
  } in
  
  (* Create the router signal - fresh per provide call, not global *)
  let current, set_current = Signal.create initial_state in
  
  (* Create navigate function *)
  let navigate new_path =
    let new_path_parsed, new_query, new_hash = Router.parse_url new_path in
    let new_params =
      match Router.match_path routes new_path_parsed with
      | Some (_, result) -> result.params
      | None -> Route.Params.empty
    in
    set_current {
      path = new_path_parsed;
      params = new_params;
      query = new_query;
      hash = new_hash;
    }
  in
  
  let router_ctx : Router.router_context = {
    current;
    set_current;
    navigate;
  } in
  
  Context.provide Router.context router_ctx f

(** {1 Link Component} *)

(** Create a Link component that renders as an anchor tag.
    
    On the server, this renders a regular anchor.
    On the browser, clicks will be intercepted for client-side navigation.
    
    @param href The target URL
    @param class_ Optional CSS class
    @param children Child nodes *)
let link ?(class_="") ~href ~children () =
  if class_ = "" then
    Solid_ml_html.Html.a ~href ~children ()
  else
    Solid_ml_html.Html.a ~class_ ~href ~children ()

(** Create a NavLink that adds an active class when matching.
    
    @param href The target URL
    @param class_ Base CSS class (optional)
    @param active_class Class to add when active (default: "active")
    @param exact If true, path must match exactly. If false (default), 
                 current path starting with href counts as active.
    @param children Child nodes *)
let nav_link ?(class_="") ?(active_class="active") ?(exact=false) ~href ~children () =
  (* Get current path to check if link is active *)
  let current_path = Router.use_path () in
  
  (* Check if this link is active *)
  let is_active = 
    if exact then
      current_path = href
    else
      (* Partial match: /users is active when viewing /users/123 *)
      current_path = href || 
      (href <> "/" && String.length current_path > String.length href &&
       String.sub current_path 0 (String.length href) = href &&
       current_path.[String.length href] = '/')
  in
  
  (* Build class string *)
  let final_class = 
    if is_active then
      if class_ = "" then active_class else class_ ^ " " ^ active_class
    else
      class_
  in
  
  if final_class = "" then
    Solid_ml_html.Html.a ~href ~children ()
  else
    Solid_ml_html.Html.a ~class_:final_class ~href ~children ()

(** {1 Outlet Component} *)

(** Render the matched route's component.
    
    This looks up the current route and renders its associated component.
    If no route matches, renders nothing (or a 404 component if provided).
    
    @param routes List of routes where data is a component function
    @param not_found Optional component to render when no route matches *)
let outlet ~(routes : (unit -> Solid_ml_html.Html.node) Route.t list) ?not_found () =
  let path = Router.use_path () in
  
  match Route.match_routes routes path with
  | Some (route, _result) ->
    (* Get the component from the route data and render it *)
    let component = Route.data route in
    component ()
  | None ->
    match not_found with
    | Some render_404 -> render_404 ()
    | None -> Solid_ml_html.Html.fragment []

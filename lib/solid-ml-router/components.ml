(** Router components for server-side rendering.
    
    These components render to HTML on the server. The browser-side
    implementation will enhance them with client-side navigation.
*)

open Solid_ml

(** {1 Router Provider} *)

(** Configuration for the router *)
type router_config = {
  routes : unit Route.t list;
  initial_path : string;
}

(** Initialize the router with the given configuration.
    
    This sets up the router context with:
    - The initial navigation state based on the current path
    - Route matching to extract params
    
    On the server, the initial_path should be the request URL.
    On the browser, it should be window.location.pathname.
    
    @param config Router configuration
    @param f Function to run with the router context *)
let provide ~config f =
  let path, query, hash = Router.parse_url config.initial_path in
  
  (* Match against routes to get params *)
  let params = 
    match Router.match_path config.routes path with
    | Some (_, result) -> result.params
    | None -> Route.Params.empty
  in
  
  let initial_state : Router.nav_state = {
    path;
    params;
    query;
    hash;
  } in
  
  (* Create the router signal *)
  let current, set_current = Signal.create initial_state in
  
  (* Create navigate function (no-op on server, will be enhanced on browser) *)
  let navigate new_path =
    let new_path_parsed, new_query, new_hash = Router.parse_url new_path in
    let new_params =
      match Router.match_path config.routes new_path_parsed with
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

(** Props for the Link component *)
type link_props = {
  href : string;
  class_ : string option;
  active_class : string option;  (** Class to add when link matches current path *)
  children : Solid_ml_html.Html.node list;
}

(** Create a Link component that renders as an anchor tag.
    
    On the server, this renders a regular anchor.
    On the browser, clicks will be intercepted for client-side navigation.
    
    @param href The target URL
    @param class_ Optional CSS class
    @param active_class Optional class to add when the link's href matches current path
    @param children Child nodes *)
let link ?(class_="") ?active_class ~href ~children () =
  (* Get current path to check if link is active *)
  let current_path = Router.use_path () in
  
  (* Check if this link is active *)
  let is_active = current_path = href in
  
  (* Build class string *)
  let final_class = 
    match active_class with
    | Some ac when is_active -> 
      if class_ = "" then ac else class_ ^ " " ^ ac
    | _ -> class_
  in
  
  (* Render as anchor tag *)
  if final_class = "" then
    Solid_ml_html.Html.a ~href ~children ()
  else
    Solid_ml_html.Html.a ~class_:final_class ~href ~children ()

(** Create a NavLink that adds an active class when matching *)
let nav_link ?(class_="") ?(active_class="active") ~href ~children () =
  link ~class_ ~active_class ~href ~children ()

(** {1 Outlet Component} *)

(** Render the matched route's component.
    
    This looks up the current route and renders its associated component.
    If no route matches, renders nothing (or a 404 component if provided).
    
    @param routes List of routes with component functions
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

(** Router components, parameterized over HTML implementation.
    
    These components render to HTML using the provided Html module.
    For SSR defaults, use [Solid_ml_ssr.Router_components]. *)

open Solid_ml

module Signal = Signal.Unsafe

module Make (Html : sig
  type node
  type event
  val a : ?id:string -> ?class_:string -> ?href:string -> ?target:string -> ?rel:string -> ?download:string -> ?hreflang:string -> ?tabindex:int -> ?onclick:(event -> unit) -> ?data:(string * string) list -> ?attrs:(string * string) list -> children:node list -> unit -> node
  val fragment : node list -> node
end) = struct
  
(** {1 Router Provider} *)

(** Initialize the router with the given path and routes.
    ... (omitted for brevity, same implementation but using local Html module) ...
*)
let provide ~initial_path ?(routes=[]) f =
  let path, query, hash = Router.parse_url initial_path in
  
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
  
  let current, set_current = Signal.create initial_state in
  
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

let link ?(class_="") ~href ~children () =
  if class_ = "" then
    Html.a ~href ~children ()
  else
    Html.a ~class_ ~href ~children ()

let nav_link ?(class_="") ?(active_class="active") ?(exact=false) ~href ~children () =
  let current_path = Router.use_path () in
  let is_active = 
    if exact then
      current_path = href
    else
      current_path = href || 
      (href <> "/" && String.length current_path > String.length href &&
       String.sub current_path 0 (String.length href) = href &&
       current_path.[String.length href] = '/')
  in
  let final_class = 
    if is_active then
      if class_ = "" then active_class else class_ ^ " " ^ active_class
    else
      class_
  in
  if final_class = "" then
    Html.a ~href ~children ()
  else
    Html.a ~class_:final_class ~href ~children ()

(** {1 Outlet Component} *)

let outlet ~(routes : (unit -> Html.node) Route.t list) ?not_found () =
  let path = Router.use_path () in
  match Route.match_routes routes path with
  | Some (route, _result) ->
    let component = Route.data route in
    component ()
  | None ->
    match not_found with
    | Some render_404 -> render_404 ()
    | None -> Html.fragment []
end

(* This module provides a functor. Instantiate it with your Html implementation. *)

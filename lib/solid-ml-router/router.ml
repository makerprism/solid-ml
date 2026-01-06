(** Router state and navigation.
    
    This module provides:
    - Current route state (reactive signal)
    - Navigation functions
    - Route matching against registered routes
    
    The router uses context to share state across the component tree,
    allowing nested components to access route information and navigate.
*)

open Solid_ml

(** {1 Types} *)

(** Navigation state *)
type nav_state = {
  path : string;
  params : Route.Params.t;
  query : string option;
  hash : string option;
}

(** Router context containing current route and navigation functions *)
type router_context = {
  current : nav_state Signal.t;
  set_current : nav_state -> unit;
  navigate : string -> unit;
}

(** {1 Context} *)

(** Default router context (before initialization) *)
let default_nav_state = {
  path = "/";
  params = Route.Params.empty;
  query = None;
  hash = None;
}

(** Create the default signal for the context *)
let default_signal, default_setter = Signal.create default_nav_state

(** The router context, shared across the component tree *)
let context : router_context Context.t = 
  Context.create {
    current = default_signal;
    set_current = default_setter;
    navigate = (fun _ -> ());
  }

(** {1 Accessing Router State} *)

(** Get the current navigation state signal.
    Use inside effects to react to route changes. *)
let use_location () =
  let ctx = Context.use context in
  ctx.current

(** Get the current path *)
let use_path () =
  let loc = use_location () in
  Signal.get loc |> fun s -> s.path

(** Get the current params *)
let use_params () =
  let loc = use_location () in
  Signal.get loc |> fun s -> s.params

(** Get a specific param value *)
let use_param name =
  let params = use_params () in
  Route.Params.get name params

(** {1 Navigation} *)

(** Navigate to a new path.
    This updates the current route and (on browser) pushes to history. *)
let navigate path =
  let ctx = Context.use context in
  ctx.navigate path

(** Navigate back in history (browser only, no-op on server) *)
let go_back () = ()  (* Will be overridden in browser implementation *)

(** Navigate forward in history (browser only, no-op on server) *)
let go_forward () = ()  (* Will be overridden in browser implementation *)

(** {1 Route Matching} *)

(** Match a path against a list of routes and return the matching route and params *)
let match_path routes path =
  Route.match_routes routes path

(** {1 URL Parsing} *)

(** Parse a URL into its components: path, query, hash *)
let parse_url url =
  (* Split off hash first *)
  let url, hash = 
    match String.index_opt url '#' with
    | Some i -> 
      String.sub url 0 i,
      Some (String.sub url (i + 1) (String.length url - i - 1))
    | None -> url, None
  in
  (* Then split off query string *)
  let path, query =
    match String.index_opt url '?' with
    | Some i ->
      String.sub url 0 i,
      Some (String.sub url (i + 1) (String.length url - i - 1))
    | None -> url, None
  in
  (path, query, hash)

(** Build a URL from components *)
let build_url ~path ?query ?hash () =
  let url = path in
  let url = match query with
    | Some q -> url ^ "?" ^ q
    | None -> url
  in
  let url = match hash with
    | Some h -> url ^ "#" ^ h
    | None -> url
  in
  url

(** {1 Query String Parsing} *)

(** Parse a query string into key-value pairs.
    Example: "foo=bar&baz=qux" -> [("foo", "bar"); ("baz", "qux")] *)
let parse_query_string query =
  if query = "" then []
  else
    String.split_on_char '&' query
    |> List.filter_map (fun pair ->
      match String.index_opt pair '=' with
      | Some i ->
        let key = String.sub pair 0 i in
        let value = String.sub pair (i + 1) (String.length pair - i - 1) in
        Some (key, value)
      | None ->
        (* Key without value *)
        Some (pair, "")
    )

(** Get a query parameter value *)
let get_query_param key query =
  match query with
  | None -> None
  | Some q ->
    let pairs = parse_query_string q in
    List.assoc_opt key pairs

(** Browser-side router with History API integration.
    
    This module provides client-side navigation without page reloads.
    It integrates with the browser's History API to:
    - Push new entries when navigating
    - Handle back/forward button clicks via popstate
    - Optionally restore scroll position
    
    Usage:
    {[
      open Solid_ml_browser
      
      (* Define routes *)
      let routes = [
        Router.Route.create ~path:"/" ~data:home_component;
        Router.Route.create ~path:"/about" ~data:about_component;
        Router.Route.create ~path:"/users/:id" ~data:user_component;
      ]
      
      (* Initialize the router *)
      let () =
        match Dom.get_element_by_id Dom.document "app" with
        | Some root ->
          let _dispose = Router.init ~routes (fun () ->
            Render.render root (fun () ->
              Router.outlet ~routes ()
            )
          ) in ()
        | None -> ()
    ]}
*)

(** Debug logging *)
external console_log : string -> unit = "log" [@@mel.scope "console"]

(** {1 Route Module} *)

(** Route pattern matching - mirrors solid-ml-router for browser use *)
module Route = struct
  (** Parameters extracted from route matching *)
  module Params = struct
    type t = (string * string) list
    
    let empty : t = []
    
    let get key (params : t) =
      List.assoc_opt key params
    
    let get_exn key (params : t) =
      List.assoc key params
    
    let add key value (params : t) : t =
      (key, value) :: params
  end

  type segment =
    | Static of string
    | Param of string
    | Wildcard

  type pattern = segment list

  type match_result = {
    params : Params.t;
    path : string;
  }

  type 'a t = {
    pattern : pattern;
    path_template : string;
    data : 'a;
  }

  let parse_pattern path =
    let segments = String.split_on_char '/' path in
    let segments = match segments with
      | "" :: rest -> rest
      | segs -> segs
    in
    List.map (fun seg ->
      if String.length seg > 0 && seg.[0] = ':' then
        Param (String.sub seg 1 (String.length seg - 1))
      else if seg = "*" then
        Wildcard
      else
        Static seg
    ) segments

  let match_pattern pattern path =
    let path_segments = String.split_on_char '/' path in
    let path_segments = match path_segments with
      | "" :: rest -> rest
      | segs -> segs
    in
    
    let rec match_segments pattern_segs path_segs params =
      match pattern_segs, path_segs with
      | [], [] -> Some params
      | [], [""] -> Some params
      | [], _ -> None
      | [Wildcard], rest ->
        let wildcard_value = String.concat "/" rest in
        Some (Params.add "*" wildcard_value params)
      | Wildcard :: _, _ -> None
      | _, [] -> None
      | Static s :: pattern_rest, seg :: path_rest when s = seg ->
        match_segments pattern_rest path_rest params
      | Static _ :: _, _ -> None
      | Param name :: pattern_rest, seg :: path_rest when seg <> "" ->
        match_segments pattern_rest path_rest (Params.add name seg params)
      | Param _ :: _, _ -> None
    in
    
    match_segments pattern path_segments Params.empty

  let create ~path ~data =
    let pattern = parse_pattern path in
    { pattern; path_template = path; data }

  let match_route route path =
    match match_pattern route.pattern path with
    | Some params -> Some { params; path }
    | None -> None

  let match_routes routes path =
    let rec try_routes = function
      | [] -> None
      | route :: rest ->
        match match_route route path with
        | Some result -> Some (route, result)
        | None -> try_routes rest
    in
    try_routes routes

  let path_template route = route.path_template
  let data route = route.data
end

(** {1 Types} *)

(** Navigation state *)
type nav_state = {
  path : string;
  params : Route.Params.t;
  query : string option;
  hash : string option;
}

(** Router context *)
type router_context = {
  current : nav_state Reactive_core.signal;
  set_current : nav_state -> unit;
  routes : unit Route.t list;
}

(** Router configuration *)
type config = {
  routes : unit Route.t list;
  base : string;  (** Base path to strip from URLs (e.g., "/app" or "/browser_router") *)
  scroll_restoration : bool;
}

let default_config = {
  routes = [];
  base = "";
  scroll_restoration = true;
}

(** {1 Exceptions} *)

exception No_router_context

(** {1 Internal State} *)

(** Scroll positions stored by URL - using JS Map to avoid heavy stdlib deps *)
let scroll_positions : (string, float * float) Dom.js_map = Dom.js_map_create ()
let current_config : config ref = ref default_config
let popstate_handler : (Dom.event -> unit) option ref = ref None

(** Marker for uninitialized context *)
let uninitialized_setter _ = raise No_router_context

let no_context_sentinel : router_context = {
  current = Obj.magic ();
  set_current = uninitialized_setter;
  routes = [];
}

let context : router_context Reactive_core.context = 
  Reactive_core.create_context no_context_sentinel

(** {1 URL Helpers} *)

let parse_url url =
  let url, hash = 
    match String.index_opt url '#' with
    | Some i -> 
      String.sub url 0 i,
      Some (String.sub url (i + 1) (String.length url - i - 1))
    | None -> url, None
  in
  let path, query =
    match String.index_opt url '?' with
    | Some i ->
      String.sub url 0 i,
      Some (String.sub url (i + 1) (String.length url - i - 1))
    | None -> url, None
  in
  (path, query, hash)

let get_current_url () =
  let path = Dom.get_pathname () in
  let search = Dom.get_search () in
  let hash = Dom.get_hash () in
  path ^ search ^ hash

(** Strip base path from a URL path *)
let strip_base base path =
  if base = "" then path
  else if String.length path >= String.length base && 
          String.sub path 0 (String.length base) = base then
    let rest = String.sub path (String.length base) (String.length path - String.length base) in
    if rest = "" then "/" else rest
  else path

(** Get path with base stripped *)
let get_app_path () =
  let path = Dom.get_pathname () in
  let app_path = strip_base !current_config.base path in
  (* Also strip index.html if present *)
  if String.length app_path > 11 && 
     String.sub app_path (String.length app_path - 11) 11 = "/index.html" then
    String.sub app_path 0 (String.length app_path - 11)
  else if app_path = "/index.html" then "/"
  else app_path

(** {1 Accessing Router State} *)

let use_location () =
  let ctx = Reactive_core.use_context context in
  if ctx.set_current == uninitialized_setter then raise No_router_context;
  ctx.current

let use_path () =
  let loc = use_location () in
  (Reactive_core.get_signal loc).path

let use_params () =
  let loc = use_location () in
  (Reactive_core.get_signal loc).params

let use_param name =
  let params = use_params () in
  Route.Params.get name params

(** {1 Navigation} *)

let navigate ?(replace=false) url =
  (* Save current scroll position *)
  if !current_config.scroll_restoration then begin
    let current_url = get_current_url () in
    let scroll_x = Dom.get_scroll_x () in
    let scroll_y = Dom.get_scroll_y () in
    Dom.js_map_set_ scroll_positions current_url (scroll_x, scroll_y)
  end;
  
  (* The url is an app-relative path like "/users" *)
  (* We need to prepend the base for the browser history *)
  let browser_url = !current_config.base ^ url in
  
  (* Update history *)
  if replace then
    Dom.replace_state browser_url
  else
    Dom.push_state browser_url;
  
  (* Update router state with the app-relative path *)
  let path, query, hash = parse_url url in
  let params = 
    match Route.match_routes !current_config.routes path with
    | Some (_, result) -> result.params
    | None -> Route.Params.empty
  in
  
  (try
    let ctx = Reactive_core.use_context context in
    if ctx.set_current != uninitialized_setter then begin
      ctx.set_current { path; params; query; hash };
      (* Scroll to top on new navigation *)
      if not replace && !current_config.scroll_restoration then
        Dom.scroll_to_top ()
    end
  with _ -> ())

let go_back () = Dom.history_back ()
let go_forward () = Dom.history_forward ()
let go delta = Dom.history_go delta

(** {1 Popstate Handler} *)

let handle_popstate _evt =
  let full_url = get_current_url () in
  let app_path = get_app_path () in
  let _, query, hash = parse_url full_url in
  let params = 
    match Route.match_routes !current_config.routes app_path with
    | Some (_, result) -> result.params
    | None -> Route.Params.empty
  in
  
  (try
    let ctx = Reactive_core.use_context context in
    if ctx.set_current != uninitialized_setter then begin
      ctx.set_current { path = app_path; params; query; hash };
      
      (* Restore scroll position *)
      if !current_config.scroll_restoration then begin
        match Dom.js_map_get_opt scroll_positions full_url with
        | Some (x, y) -> 
          let _ = Dom.set_timeout (fun () -> Dom.scroll_to x y) 0 in ()
        | None -> ()
      end
    end
  with _ -> ())

(** {1 Initialization} *)

let provide ~initial_path ~routes f =
  let path, query, hash = parse_url initial_path in
  let params = 
    match Route.match_routes routes path with
    | Some (_, result) -> result.params
    | None -> Route.Params.empty
  in
  
  let initial_state = { path; params; query; hash } in
  let current = Reactive_core.create_signal initial_state in
  let set_current state = Reactive_core.set_signal current state in
  
  let router_ctx = { current; set_current; routes } in
  Reactive_core.provide_context context router_ctx f

let init ?(config=default_config) f =
  current_config := config;
  
  (* Set up popstate listener *)
  let handler = handle_popstate in
  Dom.on_popstate handler;
  popstate_handler := Some handler;
  
  (* Get initial app-relative path (with base stripped) *)
  let initial_path = get_app_path () in
  
  (* Run with router context *)
  let (result, root_dispose) = Reactive_core.create_root (fun () ->
    provide ~initial_path ~routes:config.routes f
  ) in
  
  (* Return dispose function *)
  let dispose () =
    root_dispose ();
    (match !popstate_handler with
     | Some h -> 
       Dom.off_popstate h;
       popstate_handler := None
     | None -> ())
  in
  
  (result, dispose)

(** {1 Link Components} *)

let link ?(class_="") ~href ~children () =
  (* href is app-relative, but we show the full URL in the DOM *)
  let browser_href = !current_config.base ^ href in
  (* Capture the context now, while we're inside the reactive root *)
  let ctx = Reactive_core.use_context context in
  let onclick = fun evt ->
    if Dom.mouse_button evt = 0 
       && not (Dom.keyboard_ctrl_key evt)
       && not (Dom.keyboard_shift_key evt)
       && not (Dom.keyboard_alt_key evt)
       && not (Dom.keyboard_meta_key evt) then begin
      Dom.prevent_default evt;
      (* Use the captured context directly instead of looking it up *)
      if ctx.set_current != uninitialized_setter then begin
        let path, query, hash = parse_url href in
        let params = 
          match Route.match_routes !current_config.routes path with
          | Some (_, result) -> result.params
          | None -> Route.Params.empty
        in
        (* Update history *)
        Dom.push_state browser_href;
        (* Update router state *)
        ctx.set_current { path; params; query; hash };
        if !current_config.scroll_restoration then
          Dom.scroll_to_top ()
      end
    end
  in
  Html.a ~href:browser_href ?class_:(if class_ = "" then None else Some class_) ~onclick ~children ()

let nav_link ?(class_="") ?(active_class="active") ?(exact=false) ~href ~children () =
  let current_path = use_path () in
  (* Capture the context now, while we're inside the reactive root *)
  let ctx = Reactive_core.use_context context in
  
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
  
  (* href is app-relative, but we show the full URL in the DOM *)
  let browser_href = !current_config.base ^ href in
  let onclick = fun evt ->
    if Dom.mouse_button evt = 0 
       && not (Dom.keyboard_ctrl_key evt)
       && not (Dom.keyboard_shift_key evt)
       && not (Dom.keyboard_alt_key evt)
       && not (Dom.keyboard_meta_key evt) then begin
      Dom.prevent_default evt;
      (* Use the captured context directly instead of looking it up *)
      if ctx.set_current != uninitialized_setter then begin
        let path, query, hash = parse_url href in
        let params = 
          match Route.match_routes !current_config.routes path with
          | Some (_, result) -> result.params
          | None -> Route.Params.empty
        in
        (* Update history *)
        Dom.push_state browser_href;
        (* Update router state *)
        ctx.set_current { path; params; query; hash };
        if !current_config.scroll_restoration then
          Dom.scroll_to_top ()
      end
    end
  in
  
  Html.a ~href:browser_href ?class_:(if final_class = "" then None else Some final_class) ~onclick ~children ()

(** {1 Outlet Component} *)

let outlet ~(routes : (unit -> Html.node) Route.t list) ?not_found () =
  (* Create a container element that will be updated reactively *)
  let container = Dom.create_element Dom.document "div" in
  let current_path = ref "" in
  
  (* Effect that re-renders the outlet when the path changes *)
  Reactive_core.create_effect (fun () ->
    let path = use_path () in
    
    (* Only re-render if the path actually changed *)
    if path <> !current_path then begin
      current_path := path;
      
      (* Clear existing content *)
      Dom.set_inner_html container "";
      
      (* Render the matched route - use untrack so component's internal
         signals don't cause the outlet to re-render *)
      let node = Reactive_core.untrack (fun () ->
        match Route.match_routes routes path with
        | Some (route, _result) ->
          let component = Route.data route in
          component ()
        | None ->
          match not_found with
          | Some render_404 -> render_404 ()
          | None -> Html.empty
      ) in
      
      (* Append the new content *)
      Html.append_to_element container node
    end
  );
  
  Html.Element container

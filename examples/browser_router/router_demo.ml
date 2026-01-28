(** Interactive router example for the browser.
    
    This example demonstrates:
    - Server-side rendering with client hydration
    - Client-side navigation without page reloads
    - Dynamic route parameters and wildcards
    - NavLink active styling
    
    Build with: make example-browser-router
    Run server with: make run-browser-router-server
*)

open Solid_ml_browser

let () =
  let module Router_browser = struct
    type node = Solid_ml_browser.Html.node
    type filters = Solid_ml_internal.Filter.filters
    include Router
  end in
  let module Shared = Shared_components.Make(Solid_ml_browser.Env)(Router_browser)(struct let base = "" end) in
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some root ->
    let config = Router.{ 
      routes = Shared.config_routes; 
      base = "/browser_router";
      scroll_restoration = true 
    } in
    Router.current_config := config;
    let handler = Router.handle_popstate in
    Dom.on_popstate handler;
    Router.popstate_handler := Some handler;
    let initial_path = Router.get_app_path () in
    let child_nodes = Dom.get_child_nodes root in
    let _render_dispose =
      if Array.length child_nodes = 0 then
        Render.render root (fun () ->
          Router.provide ~initial_path ~routes:config.routes (fun () ->
            Shared.app ()
          ))
      else
        Render.hydrate root (fun () ->
          Router.provide ~initial_path ~routes:config.routes (fun () ->
            Shared.app ()
          ))
    in
    Dom.log "solid-ml router demo initialized!"
  | None ->
    Dom.error "Could not find #app element"

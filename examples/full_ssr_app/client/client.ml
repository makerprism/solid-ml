(** Full SSR App Example - Client Hydration
    
    This script hydrates the server-rendered HTML by running the SAME component logic
    as the server, but using the Browser backend.
*)

open Solid_ml_browser
module Shared = Shared_components.Components.Make(Solid_ml_browser.Env)
module Routes = Shared_components.Routes

(** {1 Shared Data Types} *)
(* open Shared_components *)

(** {1 DOM Helpers} *)

let get_element id =
  Dom.get_element_by_id (Dom.document ()) id


(** {1 Client-Side Navigation} *)

(** Set up client-side navigation for all nav links *)
let setup_navigation () =
  let _dispose =
    Navigation.bind_links
      ~selector:"nav a.nav-link"
      ~history:`None
      ~on_navigate:Dom.set_location
      ()
  in
  ()

(** {1 Hydration Logic} *)

let hydrate_counter () =
  match get_element "app", get_element "initial-count" with
  | Some app_el, Some initial_el ->
    (* Get initial value from hidden input *)
    let initial = 
      match Dom.get_attribute initial_el "value" with
      | Some v -> (try int_of_string v with _ -> 0)
      | None -> 0
    in
    
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Counter)
          ~children:(Shared.counter_content ~initial ())
          ())
    in
    
    Dom.log "Counter hydrated!"
  | _ -> ()

let hydrate_todos () =
  match get_element "app" with
  | Some app_el ->
    (* For simplicity in this demo, we recreate the initial state manually
       In a real app, we'd serialize the state to JSON in the HTML *)
    let initial_todos = [
       Shared_components.Components.{ id = 1; text = "Learn solid-ml"; completed = true };
       Shared_components.Components.{ id = 2; text = "Build an SSR app"; completed = false };
       Shared_components.Components.{ id = 3; text = "Add hydration"; completed = false };
       Shared_components.Components.{ id = 4; text = "Deploy to production"; completed = false };
    ] in
    
    (* Hydrate the shared component *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Todos)
          ~children:(Shared.todos_content ~initial_todos ())
          ())
    in
    
    Dom.log "Todos hydrated!"
  | None -> ()

let show_hydration_status () =
  match get_element "hydration-status" with
  | Some el -> Dom.add_class el "active"
  | None -> ()

(** {1 Main Entry Point} *)

let () =
  (* Initialize the reactive runtime *)
  let (_result, _dispose) = Reactive_core.create_root (fun () ->
    let path = Dom.get_pathname () in
    Dom.log ("Hydrating page: " ^ path);

    if path = Routes.path Routes.Counter then
      hydrate_counter ()
    else if path = Routes.path Routes.Todos then
      hydrate_todos ()
    else if path = Routes.path Routes.Home then (
      match get_element "app" with
      | None -> ()
      | Some app_el ->
        let _dispose =
          Render.render app_el (fun () ->
            Shared.app_layout
              ~current_path:(Routes.path Routes.Home)
              ~children:(Shared.home_page ())
              ())
        in
        ()
    )
    else if path = Routes.path Routes.Keyed then (
      match get_element "app" with
      | None -> ()
      | Some app_el ->
        (* True hydration: adopt existing DOM. *)
        let _dispose =
          Render.render app_el (fun () ->
            Shared.app_layout
              ~current_path:(Routes.path Routes.Keyed)
              ~children:(Shared.keyed_demo ())
              ())
        in
        ()
    )
    else if path = Routes.path Routes.Template_keyed then (
      match get_element "app" with
      | None -> ()
      | Some app_el ->
        let module T = Shared_components.Template_keyed.Make (Solid_ml_browser.Env) in
        let _dispose =
          Render.render app_el (fun () ->
            Shared.app_layout
              ~current_path:(Routes.path Routes.Template_keyed)
              ~children:(T.view ())
              ())
        in
        ()
    );

    setup_navigation ();
    show_hydration_status ();

    Dom.log "Hydration complete!"
  ) in
  ()

(** Full SSR App Example - Client Hydration
    
    This script hydrates the server-rendered HTML by running the SAME component logic
    as the server, but using the Browser backend.
*)

open Solid_ml_browser
module Shared = Shared_components.Components.Make(Client_platform.Client_Platform)

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

(** Extract todo ID from element id like "todo-123" *)
let extract_todo_id el =
  match Dom.get_attribute el "id" with
  | Some id_str when String.length id_str > 5 && String.sub id_str 0 5 = "todo-" ->
    (try Some (int_of_string (String.sub id_str 5 (String.length id_str - 5))) with _ -> None)
  | _ -> None

let hydrate_counter () =
  match get_element "app", get_element "initial-count" with
  | Some app_el, Some initial_el ->
    (* Get initial value from hidden input *)
    let initial = 
      match Dom.get_attribute initial_el "value" with
      | Some v -> (try int_of_string v with _ -> 0)
      | None -> 0
    in
    
    (* Hydrate the shared component. *)
    (* We need to cast the node type because strict typing separates
       Client_platform.Html.node from Solid_ml_browser.Html.node
       even though they are the same underlying type *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
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
    let initial_todos = Shared_components.Components.[
       { id = 1; text = "Learn solid-ml"; completed = true };
       { id = 2; text = "Build an SSR app"; completed = false };
       { id = 3; text = "Add hydration"; completed = false };
       { id = 4; text = "Deploy to production"; completed = false };
    ] in
    
    (* Hydrate the shared component *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
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

    if path = "/counter" then
      hydrate_counter ()
    else if path = "/todos" then
      hydrate_todos ()
    else if path = "/keyed" then (
      match get_element "app" with
      | None -> ()
      | Some app_el ->
        (* True hydration: adopt existing DOM. *)
        let _dispose =
          Render.render app_el (fun () ->
            Shared.app_layout ~children:(Shared.keyed_demo ()) ())
        in
        ()
    )
    else if path = "/template-keyed" then (
      match get_element "app" with
      | None -> ()
      | Some app_el ->
        let module T = Shared_components.Template_keyed.Make (Solid_ml_browser.Env) in
        let _dispose =
          Render.render app_el (fun () ->
            Shared.app_layout ~children:(T.view ()) ())
        in
        ()
    );

    setup_navigation ();
    show_hydration_status ();

    Dom.log "Hydration complete!"
  ) in
  ()

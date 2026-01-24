(** Full SSR App Example - Client Hydration
    
    This script hydrates the server-rendered HTML by running the SAME component logic
    as the server, but using the Browser backend.
*)

open Solid_ml_browser
module Shared = Shared_components.Components.Make(Solid_ml_browser.Env)
module Routes = Shared_components.Routes
module Filters = Shared_components.Filters.Make(Solid_ml_browser.Env)

(** {1 Shared Data Types} *)
(* open Shared_components *)

(** {1 DOM Helpers} *)

let get_element id =
  Dom.get_element_by_id (Dom.document ()) id

let decode_int (json : Js.Json.t) : int option =
  match Js.Json.decodeNumber json with
  | None -> None
  | Some v -> Some (int_of_float v)

let decode_string (json : Js.Json.t) : string option =
  Js.Json.decodeString json

let decode_bool (json : Js.Json.t) : bool option =
  Js.Json.decodeBoolean json

let decode_field obj name decode =
  match Js.Dict.get obj name with
  | None -> None
  | Some value -> decode value

let decode_todo (json : Js.Json.t) : Shared_components.Components.todo option =
  match Js.Json.decodeObject json with
  | None -> None
  | Some obj ->
    let open Shared_components.Components in
    (match decode_field obj "id" decode_int,
           decode_field obj "text" decode_string,
           decode_field obj "completed" decode_bool with
     | Some id, Some text, Some completed -> Some { id; text; completed }
     | _ -> None)

let decode_todos (json : Js.Json.t) : Shared_components.Components.todo list option =
  match Js.Json.decodeArray json with
  | None -> None
  | Some arr ->
    let rec loop acc idx =
      if idx < 0 then Some acc
      else
        match decode_todo arr.(idx) with
        | None -> None
        | Some todo -> loop (todo :: acc) (idx - 1)
    in
    loop [] (Array.length arr - 1)


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
  match get_element "app" with
  | Some app_el ->
    let counter_key = Solid_ml_browser.State.key ~namespace:"full_ssr" "counter" in
    let initial =
      Solid_ml_browser.State.decode
        ~key:counter_key
        ~decode:decode_int
        ~default:0
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
    let todos_key = Solid_ml_browser.State.key ~namespace:"full_ssr" "todos" in
    let initial_todos =
      Solid_ml_browser.State.decode
        ~key:todos_key
        ~decode:decode_todos
        ~default:[]
    in

    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Todos)
          ~children:(Shared.todos_content ~initial_todos ())
          ())
    in

    let doc = Dom.document () in
    (match Dom.query_selector doc ".todo-list" with
     | Some _list_el ->
       (* Initialize checkbox states *)
       let todos = Dom.query_selector_all doc ".todo" in
       List.iter (fun todo ->
         let todo_el = todo in
         let checkbox =
           match Dom.query_selector_within todo_el ".checkbox" with
           | Some cb -> cb
           | None -> todo_el
         in
         let initial_text = if Dom.has_class todo_el "completed" then "[X]" else "[ ]" in
         Dom.set_text_content checkbox initial_text;

         ignore (Dom.add_event_listener todo_el "click" (fun _ev ->
           let is_complete = Dom.has_class todo_el "completed" in
           if is_complete then (
             Dom.remove_class todo_el "completed";
             Dom.set_text_content checkbox "[ ]"
           ) else (
             Dom.add_class todo_el "completed";
             Dom.set_text_content checkbox "[X]"
           );
           ()
         ))
       ) todos
     | None -> ());

    Dom.log "Todos hydrated!"
  | None -> ()

let hydrate_filters () =
  match get_element "app" with
  | Some app_el ->
    let initial_todos : Shared_components.Filters.todo list = [
       { id = 1; text = "Learn solid-ml"; completed = true };
       { id = 2; text = "Build an SSR app"; completed = false };
       { id = 3; text = "Add hydration"; completed = false };
       { id = 4; text = "Deploy to production"; completed = false };
    ] in

    (* Hydrate with Filters view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Filters)
          ~children:(Filters.view ~initial_todos ())
          ())
    in

    (* Setup client-side interactivity for filter buttons *)
    let doc = Dom.document () in
    (match Dom.query_selector doc ".filter-bar" with
     | Some _filter_bar ->
       let filter_buttons = Dom.query_selector_all doc ".filter-btn" in
       List.iter (fun button ->
         ignore (Dom.add_event_listener button "click" (fun _ev ->
           (* Toggle active class manually for now *)
           let buttons = Dom.query_selector_all doc ".filter-btn" in
           List.iter (fun b -> Dom.remove_class b "active") buttons;
           Dom.add_class button "active";
           ()
         ))
       ) filter_buttons
     | None -> ());

    (* Setup search input *)
    (match Dom.query_selector doc ".search-input" with
     | Some input ->
       ignore (Dom.add_event_listener input "input" (fun _ev ->
         (* Signal should handle this, but we'll add manual listener for now *)
         ()
       ))
     | None -> ());

    (* Initialize checkboxes in filtered list *)
    (match Dom.query_selector doc ".todo-list" with
     | Some _list_el ->
       let todos = Dom.query_selector_all doc ".todo" in
       List.iter (fun todo ->
         let checkbox =
           match Dom.query_selector_within todo ".checkbox" with
           | Some cb -> cb
           | None -> todo
         in
         let initial_text = if Dom.has_class todo "completed" then "[X]" else "[ ]" in
         Dom.set_text_content checkbox initial_text;

         ignore (Dom.add_event_listener todo "click" (fun _ev ->
           let is_complete = Dom.has_class todo "completed" in
           if is_complete then (
             Dom.remove_class todo "completed";
             Dom.set_text_content checkbox "[ ]"
           ) else (
             Dom.add_class todo "completed";
             Dom.set_text_content checkbox "[X]"
           );
           ()
         ))
       ) todos
     | None -> ());

    Dom.log "Filters hydrated!"
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
    else if path = Routes.path Routes.Filters then
      hydrate_filters ()
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

(** Full SSR App Example - Client Hydration
    
    This script hydrates the server-rendered HTML by running the SAME component logic
    as the server, but using the Browser backend.
*)

open Solid_ml_browser
module Shared = Shared_components.Components.Make(Solid_ml_browser.Env)
module Routes = Shared_components.Routes
module Filters = Shared_components.Filters.Make(Solid_ml_browser.Env)
module Inline_edit = Shared_components.Inline_edit.Make(Solid_ml_browser.Env)
module Async = Shared_components.Async.Make(Solid_ml_browser.Env)
module Undo_redo = Shared_components.Undo_redo.Make(Solid_ml_browser.Env)
module Theme = Shared_components.Theme.Make(Solid_ml_browser.Env)
module Wizard = Shared_components.Wizard.Make(Solid_ml_browser.Env)

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
    Dom.log "Todos hydrated!"
  | None -> ()

let hydrate_filters () =
  match get_element "app" with
  | Some app_el ->
    let initial_todos : Shared_components.Filters.todo list = [
       { id = 1; text = "Learn solid-ml-server"; completed = true };
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
    Dom.log "Filters hydrated!"
  | None -> ()

let hydrate_inline_edit () =
  match get_element "app" with
  | Some app_el ->
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Inline_edit)
          ~children:(Inline_edit.view ())
          ())
    in
    Dom.log "Inline edit hydrated!"
  | None -> ()

let hydrate_async () =
  match get_element "app" with
  | Some app_el ->
    let schedule : delay_ms:int -> (unit -> unit) -> unit =
      [%mel.raw {|
        function (delay_ms, fn) { setTimeout(fn, delay_ms); }
      |}]
    in
    (* Hydrate with Async view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Async)
          ~children:(Async.view ~schedule ())
          ())
    in

    (* Setup client-side interactivity for refresh/retry buttons *)
    let doc = Dom.document () in

    (* Refresh buttons in resource demo *)
    (match Dom.query_selector doc ".resource-demo" with
     | Some _demo ->
         let refresh_buttons = Dom.query_selector_all doc ".btn-refresh" in
         List.iter (fun button ->
           ignore (Dom.add_event_listener button "click" (fun _ev ->
             (* Signal will handle the refresh trigger *)
             ()
           ))
         ) refresh_buttons
     | None -> ());

    (* Retry buttons in error states *)
    let retry_buttons = Dom.query_selector_all doc ".btn-retry" in
    List.iter (fun button ->
      ignore (Dom.add_event_listener button "click" (fun _ev ->
        (* Signal will handle the retry *)
        ()
      ))
    ) retry_buttons;

    (* Setup sequential demo controls *)
    (match Dom.query_selector doc ".sequential-demo" with
     | Some _demo ->
         let next_buttons = Dom.query_selector_all doc ".btn-primary" in
         List.iter (fun button ->
           ignore (Dom.add_event_listener button "click" (fun _ev ->
             (* Signal will handle the step increment *)
             ()
           ))
         ) next_buttons;

         let reset_buttons = Dom.query_selector_all doc ".btn-secondary" in
         List.iter (fun button ->
           ignore (Dom.add_event_listener button "click" (fun _ev ->
             (* Signal will handle the reset *)
             ()
           ))
         ) reset_buttons
     | None -> ());

    Dom.log "Async hydrated!"
  | None -> ()

let hydrate_undo_redo () =
  match get_element "app" with
  | Some app_el ->
    (* Hydrate with Undo_redo view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Undo_redo)
          ~children:(Undo_redo.view ())
          ())
    in

    (* Setup client-side interactivity for buttons is handled by signals *)
    Dom.log "Undo-Redo hydrated!"
  | None -> ()

let hydrate_theme () =
  match get_element "app" with
  | Some app_el ->
    let get_local_storage_item : string -> string option =
      [%mel.raw {|
        function (key) {
          try {
            if (!window.localStorage) return null;
            return window.localStorage.getItem(key);
          } catch (e) {
            return null;
          }
        }
      |}]
    in
    let set_local_storage_item : string -> string -> unit =
      [%mel.raw {|
        function (key, value) {
          try {
            if (!window.localStorage) return;
            window.localStorage.setItem(key, value);
          } catch (e) {
            return;
          }
        }
      |}]
    in
    let stored_theme () =
      match get_local_storage_item "app-theme" with
      | None -> None
      | Some value -> Theme.string_to_theme value
    in
    let initial_theme =
      match stored_theme () with
      | Some t -> t
      | None -> Theme.Light
    in
    let on_theme_change theme =
      set_local_storage_item "app-theme" (Theme.theme_to_string theme)
    in
    (* Hydrate with Theme view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Theme)
          ~children:(Theme.view ~initial_theme ~on_theme_change ())
          ())
    in

    (* Setup client-side interactivity for theme switching is handled by signals *)
    Dom.log "Theme hydrated!"
  | None -> ()

let hydrate_wizard () =
  match get_element "app" with
  | Some app_el ->
    (* Hydrate with Wizard view - the wizard uses reactive signals internally *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Wizard)
          ~children:(Wizard.view ())
          ())
    in
    Dom.log "Wizard hydrated with reactive signals!"
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
    else if path = Routes.path Routes.Inline_edit then
      hydrate_inline_edit ()
    else if path = Routes.path Routes.Async then
      hydrate_async ()
    else if path = Routes.path Routes.Undo_redo then
      hydrate_undo_redo ()
    else if path = Routes.path Routes.Theme then
      hydrate_theme ()
    else if path = Routes.path Routes.Wizard then
      hydrate_wizard ()
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

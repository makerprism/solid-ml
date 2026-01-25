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

let hydrate_inline_edit () =
  match get_element "app" with
  | Some app_el ->
    let initial_todos : Shared_components.Inline_edit.todo list = [
       { id = 1; text = "Learn solid-ml"; completed = false };
       { id = 2; text = "Build an SSR app"; completed = false };
       { id = 3; text = "Add inline editing"; completed = false };
    ] in

    (* Hydrate with Inline_edit view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Inline_edit)
          ~children:(Inline_edit.view ~initial_todos ())
          ())
    in

    (* Setup client-side interactivity for edit buttons *)
    let doc = Dom.document () in
    let edit_buttons = Dom.query_selector_all doc ".btn-edit" in
    List.iter (fun button ->
      ignore (Dom.add_event_listener button "click" (fun _ev ->
        (* Find the parent todo item and replace with edit mode *)
        let todo_item =
          match Dom.query_selector_within button ".todo-item" with
          | Some item -> item
          | None -> button
        in
        (* Get the todo text *)
        let text_span =
          match Dom.query_selector_within todo_item ".todo-text" with
          | Some span -> span
          | None -> button
        in
        let text = Dom.get_text_content text_span in

        (* Replace with edit mode - simplified implementation *)
        let _checkbox =
          match Dom.query_selector_within todo_item ".checkbox" with
          | Some cb -> cb
          | None -> todo_item
        in

        (* Create edit UI *)
        Dom.set_inner_html todo_item
          ("<span class=\"checkbox\"></span>" ^
           "<input type=\"text\" class=\"edit-input\" value=\"" ^ text ^ "\" />" ^
           "<button class=\"btn-save\">Save</button>" ^
           "<button class=\"btn-cancel\">Cancel</button>");

        (* Setup save/cancel handlers *)
        match Dom.query_selector_within todo_item ".btn-save" with
        | Some save_btn ->
            ignore (Dom.add_event_listener save_btn "click" (fun _ ->
              (* Get input value and revert to view mode *)
              let input =
                match Dom.query_selector_within todo_item ".edit-input" with
                | Some i -> i
                | None -> todo_item
              in
              let new_text = Dom.element_value input in

              (* Revert to view mode with updated text *)
              Dom.set_inner_html todo_item
                ("<span class=\"checkbox\">[ ]</span>" ^
                 "<span class=\"todo-text\">" ^ new_text ^ "</span>" ^
                 "<button class=\"btn-edit\">Edit</button>");

              (* Re-attach click handler to new edit button *)
              match Dom.query_selector_within todo_item ".btn-edit" with
              | Some new_edit_btn ->
                  ignore (Dom.add_event_listener new_edit_btn "click" (fun _ ->
                    (* Same logic as above - simplified *)
                    ()
                  ))
              | None -> ()
            ))
        | None -> ();

        match Dom.query_selector_within todo_item ".btn-cancel" with
        | Some cancel_btn ->
            ignore (Dom.add_event_listener cancel_btn "click" (fun _ ->
              (* Revert to view mode with original text *)
              Dom.set_inner_html todo_item
                ("<span class=\"checkbox\">[ ]</span>" ^
                 "<span class=\"todo-text\">" ^ text ^ "</span>" ^
                 "<button class=\"btn-edit\">Edit</button>");

              (* Re-attach click handler *)
              match Dom.query_selector_within todo_item ".btn-edit" with
              | Some new_edit_btn ->
                  ignore (Dom.add_event_listener new_edit_btn "click" (fun _ ->
                    (* Same logic as above - simplified *)
                    ()
                  ))
              | None -> ()
            ))
        | None -> ()
      ))
    ) edit_buttons;

    (* Initialize checkboxes *)
    (match Dom.query_selector doc ".todo-list" with
     | Some _list_el ->
       let todos = Dom.query_selector_all doc ".todo-item" in
       List.iter (fun todo ->
         let checkbox =
           match Dom.query_selector_within todo ".checkbox" with
           | Some cb -> cb
           | None -> todo
         in
         Dom.set_text_content checkbox "[ ]";

         ignore (Dom.add_event_listener todo "click" (fun _ev ->
           let checkbox_inner =
             match Dom.query_selector_within todo ".checkbox" with
             | Some cb -> cb
             | None -> todo
           in
           let current = Dom.get_text_content checkbox_inner in
           let new_text = if current = "[X]" then "[ ]" else "[X]" in
           Dom.set_text_content checkbox_inner new_text
         ))
       ) todos
     | None -> ());

    Dom.log "Inline edit hydrated!"
  | None -> ()

let hydrate_async () =
  match get_element "app" with
  | Some app_el ->
    (* Hydrate with Async view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Async)
          ~children:(Async.view ())
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
    (* Hydrate with Theme view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Theme)
          ~children:(Theme.view ())
          ())
    in

    (* Setup client-side interactivity for theme switching is handled by signals *)
    Dom.log "Theme hydrated!"
  | None -> ()

let hydrate_wizard () =
  match get_element "app" with
  | Some app_el ->
    (* Hydrate with Wizard view *)
    let _disposer =
      Render.render app_el (fun () ->
        Shared.app_layout
          ~current_path:(Routes.path Routes.Wizard)
          ~children:(Wizard.view ())
          ())
    in

    (* Setup client-side wizard state and navigation *)
    let doc = Dom.document () in
    (match Dom.query_selector doc "[data-wizard]" with
     | Some wizard_el ->
         (* Wizard state management *)
         let current_step = ref "Welcome" in
         let form_data = ref [
           ("step", "Welcome");
           ("name", "");
           ("email", "");
           ("age", "");
           ("theme", "light");
           ("newsletter", "false");
           ("interests", "");
         ] in

         (* Helper: Get step number *)
         let step_index = function
           | "Welcome" -> 0
           | "PersonalInfo" -> 1
           | "Preferences" -> 2
           | "Confirm" -> 3
           | "Complete" -> 4
           | _ -> 0
         in

         (* Helper: Get next/prev step *)
         let get_next_step = function
           | "Welcome" -> "PersonalInfo"
           | "PersonalInfo" -> "Preferences"
           | "Preferences" -> "Confirm"
           | "Confirm" -> "Complete"
           | "Complete" -> "Complete"
           | _ -> "Welcome"
         in

         let get_prev_step = function
           | "Welcome" -> "Welcome"
           | "PersonalInfo" -> "Welcome"
           | "Preferences" -> "PersonalInfo"
           | "Confirm" -> "Preferences"
           | "Complete" -> "Complete"
           | _ -> "Welcome"
         in

         (* Helper: Validate personal info *)
         let validate_personal () =
           let name = try List.assoc "name" !form_data with Not_found -> "" in
           let email = try List.assoc "email" !form_data with Not_found -> "" in
           let age = try List.assoc "age" !form_data with Not_found -> "" in
           let errors = ref [] in
           if String.length name = 0 then
             errors := ("name", "Name is required") :: !errors;
           if String.length email = 0 || not (try
               let re = Str.regexp_case_fold ".+@.+" in
               Str.string_match re email 0
             with _ -> false) then
             errors := ("email", "Please enter a valid email") :: !errors;
           if String.length age = 0 || not (try
               let age_int = int_of_string age in
               age_int >= 13 && age_int <= 120
             with _ -> false) then
             errors := ("age", "Please enter a valid age (13-120)") :: !errors;
           List.rev !errors
         in

         (* Helper: Update progress bar *)
         let update_progress_bar () =
           let idx = step_index !current_step in
           let circles = Dom.query_selector_all doc ".progress-circle" in
           let fills = Dom.query_selector_all doc ".progress-fill" in
           (* Update circles *)
           Array.iteri (fun i circle ->
             Dom.remove_class circle "current";
             Dom.remove_class circle "completed";
             if i = idx then Dom.add_class circle "current"
             else if i < idx then Dom.add_class circle "completed"
           ) circles;
           (* Update fill *)
           Array.iter (fun fill ->
             Dom.set_class_name fill ("progress-fill progress-step-" ^ string_of_int idx)
           ) fills
         in

         (* Helper: Show step content *)
         let show_step step_name =
           (* Hide all steps *)
           let steps = Dom.query_selector_all doc ".wizard-step" in
           List.iter (fun step -> Dom.set_style step "display" "none") (Array.to_list steps);

           (* Show current step - we need to re-render the view *)
           (* For now, let's use a simpler approach: update existing DOM *)
           ()
         in

         (* Helper: Collect form data from current step *)
         let collect_form_data () =
           match !current_step with
           | "PersonalInfo" ->
               (match Dom.query_selector doc "#wizard-name" with
                | Some input ->
                    let name = Dom.element_value input in
                    form_data := List.map (fun (k, v) ->
                      if k = "name" then (k, name) else (k, v)
                    ) !form_data
                | None -> ());
               (match Dom.query_selector doc "#wizard-email" with
                | Some input ->
                    let email = Dom.element_value input in
                    form_data := List.map (fun (k, v) ->
                      if k = "email" then (k, email) else (k, v)
                    ) !form_data
                | None -> ());
               (match Dom.query_selector doc "#wizard-age" with
                | Some input ->
                    let age = Dom.element_value input in
                    form_data := List.map (fun (k, v) ->
                      if k = "age" then (k, age) else (k, v)
                    ) !form_data
                | None -> ())
           | "Preferences" ->
               (match Dom.query_selector doc "select[name=theme]" with
                | Some select ->
                    let theme = Dom.element_value select in
                    form_data := List.map (fun (k, v) ->
                      if k = "theme" then (k, theme) else (k, v)
                    ) !form_data
                | None -> ());
               (match Dom.query_selector doc "input[name=newsletter]" with
                | Some checkbox ->
                    let checked = Dom.get_property checkbox "checked" |> Js.Boolean.to_bool in
                    form_data := List.map (fun (k, v) ->
                      if k = "newsletter" then (k, if checked then "true" else "false") else (k, v)
                    ) !form_data
                | None -> ())
           | _ -> ()
         in

         (* Setup navigation buttons *)
         let setup_navigation_buttons () =
           let buttons = Dom.query_selector_all doc ".wizard-nav button" in
           Array.iter (fun button ->
             ignore (Dom.add_event_listener button "click" (fun _ev ->
               let action = Dom.get_attribute button "data-action" |> (function None -> "" | Some a -> a) in
               match action with
               | "back" ->
                   collect_form_data ();
                   current_step := get_prev_step !current_step;
                   form_data := List.map (fun (k, v) ->
                     if k = "step" then (k, !current_step) else (k, v)
                   ) !form_data;
                   (* Trigger re-render by calling render again *)
                   let new_content = Wizard.view () in
                   (match Dom.query_selector doc ".wizard-container" with
                    | Some container -> Dom.set_inner_html container ""; (* Will be replaced by new render *)
                    | None -> ()
                   )
               | "next" ->
                   collect_form_data ();
                   (* Validate if on personal info step *)
                   if !current_step = "PersonalInfo" then
                     let errors = validate_personal () in
                     if errors <> [] then (
                       (* Show errors - for now just log *)
                       Dom.log ("Validation errors: " ^ string_of_int (List.length errors));
                       ()
                     ) else (
                       current_step := get_next_step !current_step;
                       form_data := List.map (fun (k, v) ->
                         if k = "step" then (k, !current_step) else (k, v)
                       ) !form_data
                     )
                   else (
                     current_step := get_next_step !current_step;
                     form_data := List.map (fun (k, v) ->
                       if k = "step" then (k, !current_step) else (k, v)
                     ) !form_data
                   );
                   (* Trigger re-render *)
                   (match Dom.query_selector doc ".wizard-container" with
                    | Some container -> Dom.set_inner_html container "";
                    | None -> ()
                   )
               | "submit" ->
                   collect_form_data ();
                   current_step := "Complete";
                   form_data := List.map (fun (k, v) ->
                     if k = "step" then (k, !current_step) else (k, v)
                   ) !form_data;
                   (* Trigger re-render *)
                   (match Dom.query_selector doc ".wizard-container" with
                    | Some container -> Dom.set_inner_html container "";
                    | None -> ()
                   )
               | _ -> ()
             ))
           ) buttons
         in

         setup_navigation_buttons ()
     | None -> ());

    Dom.log "Wizard hydrated!"
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

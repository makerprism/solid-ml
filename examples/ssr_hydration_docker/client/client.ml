(** Client-side hydration script for the SSR + hydration demo.

    This demonstrates the unified hydration approach:
    - Element adoption: existing DOM elements are reused
    - Text node adoption: reactive text nodes are connected via hydration markers
    - Event handlers: attached to adopted elements

    Build with: dune build examples/ssr_hydration_docker/client
*)

open Solid_ml_browser

let get_element id = Dom.get_element_by_id (Dom.document ()) id

let read_initial () =
  match get_element "counter-initial" with
  | None -> 0
  | Some hidden ->
    begin
      match Dom.get_attribute hidden "value" with
      | Some value -> (try int_of_string value with _ -> 0)
      | None -> 0
    end

module C = Ssr_hydration_shared.Components.App (Solid_ml_browser.Env)

let () =
  let initial = read_initial () in

(* Find the main element to hydrate *)
  match Dom.query_selector (Dom.document ()) "main.app" with
  | None -> Dom.warn "No main.app element found for hydration"
  | Some main_el ->
    let _dispose = Render.hydrate main_el (fun () ->
      C.view ~initial ()
    ) in
    Dom.log "solid-ml counter hydrated"

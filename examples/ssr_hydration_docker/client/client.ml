(** Client-side hydration script for the SSR + hydration demo.
    Build with: dune build examples/ssr_hydration_docker/client
*)

open Solid_ml_browser

let get_element id = Dom.get_element_by_id Dom.document id

let read_initial () =
  match get_element "counter-initial" with
  | None -> 0
  | Some hidden ->
      begin
        match Dom.get_attribute hidden "value" with
        | Some value -> (try int_of_string value with _ -> 0)
        | None -> 0
      end

let () =
  let _result, _dispose = Reactive_core.create_root (fun () ->
    match get_element "counter-value" with
    | None -> Dom.warn "#counter-value not found; nothing to hydrate"
    | Some counter_el ->
        let initial = read_initial () in
        let count, set_count = Reactive.Signal.create initial in

        (* keep SVG text in sync as well *)
        let svg_text = Dom.query_selector Dom.document "svg text" in

        Reactive.Effect.create (fun () ->
          let value = Reactive.Signal.get count in
          Dom.set_inner_html counter_el (string_of_int value);
          (match svg_text with
           | Some text_node -> Dom.set_inner_html text_node ("solid-ml " ^ string_of_int value)
           | None -> ())
        );

        let attach id action =
          match get_element id with
          | None -> ()
          | Some button -> Dom.add_event_listener button "click" (fun _ -> action ())
        in

        attach "increment" (fun () -> Reactive.Signal.update count (fun n -> n + 1));
        attach "decrement" (fun () -> Reactive.Signal.update count (fun n -> n - 1));
        attach "reset" (fun () -> set_count initial);

        (match get_element "hydration-status" with
         | Some el -> Dom.set_inner_html el "Hydrated! Try the buttons."
         | None -> ());

        Dom.log "solid-ml counter hydrated";
  ) in
  ()

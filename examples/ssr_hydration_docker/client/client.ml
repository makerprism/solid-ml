(** Client-side hydration script for the SSR + hydration demo.

    This demonstrates the unified hydration approach:
    - Element adoption: existing DOM elements are reused
    - Text node adoption: reactive text nodes are connected via hydration markers
    - Event handlers: attached to adopted elements

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

(** Counter component matching the server structure.
    During hydration, elements are adopted and reactive bindings are attached. *)
let counter_component ~initial ~set_count ~count =
  Html.(
    main ~class_:"app" ~children:[
      h1 ~children:[text "solid-ml SSR + Hydration"] ();
      p ~children:[text "This counter was rendered on the server and hydrated in the browser."] ();
      div ~class_:"counter" ~children:[
        (* Reactive.text adopts existing text node via hydration markers *)
        div ~id:"counter-value" ~class_:"counter-value" ~children:[
          Reactive.text count
        ] ();
        div ~class_:"buttons" ~children:[
          (* Event handlers are attached to adopted button elements *)
          button ~id:"decrement" ~class_:"btn"
            ~onclick:(fun _ -> Reactive.Signal.update count (fun n -> n - 1))
            ~children:[text "-"] ();
          button ~id:"increment" ~class_:"btn"
            ~onclick:(fun _ -> Reactive.Signal.update count (fun n -> n + 1))
            ~children:[text "+"] ();
          button ~id:"reset" ~class_:"btn"
            ~onclick:(fun _ -> set_count initial)
            ~children:[text "Reset"] ();
        ] ();
        (* Hidden input for initial value *)
        Html.empty
      ] ();
      (* SVG badge - also hydrated *)
      Svg.svg ~viewBox:"0 0 120 120" ~width:"180" ~height:"180" ~children:[
        Svg.circle ~cx:"60" ~cy:"60" ~r:"50" ~fill:"#4f46e5" ~children:[] ();
        Svg.text_ ~x:"60" ~y:"68" ~fill:"white"
          ~style:"font-size:24px; text-anchor:middle; font-family:system-ui;"
          ~children:[text "solid-ml"] ()
      ] ();
      p ~id:"hydration-status" ~class_:"status" ~children:[text "Hydrated! Try the buttons."] ();
      p ~class_:"info" ~children:[
        text "The counter value uses reactive_text with hydration markers for seamless client adoption.";
      ] ()
    ] ()
  )

let () =
  let initial = read_initial () in

(* Find the main element to hydrate *)
  match Dom.query_selector Dom.document "main.app" with
  | None -> Dom.warn "No main.app element found for hydration"
  | Some main_el ->
    let count, set_count = Reactive.Signal.create initial in
    let _dispose = Render.hydrate main_el (fun () ->
      counter_component ~initial ~set_count ~count
    ) in
    Dom.log "solid-ml counter hydrated"

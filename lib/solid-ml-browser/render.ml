(** Client-side rendering and hydration.
    
    Provides functions to:
    - Render components to the DOM from scratch
    - Hydrate server-rendered HTML (adopt existing DOM)
*)

(** {1 Client-Side Rendering} *)

(** Render a component into a DOM element, replacing any existing content.
    
    Returns a dispose function that cleans up effects and event handlers.
    
    @param root The DOM element to render into
    @param component The component function to render *)
let render root component =
  (* Reset hydration keys for fresh render *)
  Reactive.reset_hydration_keys ();
  
  let (_, dispose) = Reactive_core.create_root (fun () ->
    (* Clear existing content *)
    Dom.set_inner_html root "";
    
    (* Render component and append to root *)
    Reactive_core.with_mount_scope (fun () ->
      let node = component () in
      Html.append_to_element root node
    )
  ) in
  dispose

(** Render a component, appending to existing content.
    
    Returns a dispose function. *)
let render_append root component =
  (* Reset hydration keys for fresh render *)
  Reactive.reset_hydration_keys ();
  
  let (_, dispose) = Reactive_core.create_root (fun () ->
    Reactive_core.with_mount_scope (fun () ->
      let node = component () in
      Html.append_to_element root node
    )
  ) in
  dispose

(** {1 Hydration} *)

let with_hydration root (f : unit -> 'a) : 'a =
  (* Hydration is a structured phase: always tear down. *)
  if Hydration.is_hydrating () then
    failwith "solid-ml: Render.with_hydration called while already hydrating";

  Hydration.start_hydration ();
  Hydration.start_element_hydration root;

  match f () with
  | v ->
    Hydration.end_hydration ();
    v
  | exception exn ->
    (if Hydration.is_hydrating () then Hydration.end_hydration ());
    raise exn

(** Hydrate server-rendered HTML.

    This function "adopts" existing DOM nodes rendered by the server and
    attaches reactive bindings without re-rendering.

    For hydration to work correctly:
    - The component must produce the same structure as the server render
    - Reactive text nodes are matched via hydration markers
    - Elements are matched by tag name and position
    - Event handlers are attached to adopted elements

    @param root The DOM element containing server-rendered HTML
    @param component The component function (must match server render) *)
let hydrate root component =
  (* Reset hydration keys to match server's ordering *)
  Reactive.reset_hydration_keys ();

  let dispose =
    with_hydration root (fun () ->
      (* Parse hydration markers and store text node references. *)
      Hydration.parse_hydration_markers root;
      let (_, dispose) =
        Reactive_core.create_root (fun () ->
          Reactive_core.with_mount_scope (fun () ->
            let _node = component () in
            ())
        )
      in

      (* Clean up hydration markers from the DOM while still in hydration mode. *)
      Hydration.remove_hydration_markers root;
      Event_replay.replay ();
      dispose)
  in

  dispose

(** Get hydration data embedded in the page by the server.
    
    The server embeds data as:
    <script>window.__SOLID_ML_DATA__ = {...};</script>
    
    Returns None if no data is present. *)
let get_hydration_data () =
  Js.Nullable.toOption (Dom.get_hydration_data ())

let hydrate_with root ?decode ~default component =
  let state =
    match decode, get_hydration_data () with
    | None, _ -> default
    | Some decode_fn, Some json ->
      (match decode_fn json with
       | Some v -> v
       | None -> default)
    | Some _, None -> default
  in
  hydrate root (fun () -> component state)

(** {1 Hot Module Replacement Support} *)

(** State for HMR - tracks the current dispose function *)
let hmr_dispose : (unit -> unit) option ref = ref None

(** Render with HMR support. Re-calling this will dispose the previous
    render and create a new one. Useful during development. *)
let render_hmr root component =
  (* Dispose previous render if any *)
  (match !hmr_dispose with
   | Some dispose -> dispose ()
   | None -> ());
  (* Render and store dispose function *)
  let dispose = render root component in
  hmr_dispose := Some dispose;
  dispose

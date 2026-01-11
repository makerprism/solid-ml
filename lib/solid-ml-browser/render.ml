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
    let node = component () in
    Html.append_to_element root node
  ) in
  dispose

(** Render a component, appending to existing content.
    
    Returns a dispose function. *)
let render_append root component =
  (* Reset hydration keys for fresh render *)
  Reactive.reset_hydration_keys ();
  
  let (_, dispose) = Reactive_core.create_root (fun () ->
    let node = component () in
    Html.append_to_element root node
  ) in
  dispose

(** {1 Hydration} *)

(** Hydrate server-rendered HTML.

    This function "adopts" existing DOM nodes rendered by the server and
    attaches reactive bindings without re-rendering.

    How it works:
    1. Parse hydration markers to find existing text nodes
    2. Enable hydration mode
    3. Initialize element cursor at the root
    4. Run the component to set up the reactive graph (adopting elements and text)
    5. Clean up hydration markers from the DOM
    6. Disable hydration mode

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

  (* Parse hydration markers and store text node references *)
  Hydration.parse_hydration_markers root;

  (* Enable hydration mode *)
  Hydration.start_hydration ();

  (* Initialize element cursor at root for element adoption *)
  Hydration.start_element_hydration root;

  let (_, dispose) = Reactive_core.create_root (fun () ->
    (* Run the component to set up the reactive graph.

       During hydration mode:
       - Elements are adopted from existing DOM by matching tag name and position
       - Reactive text functions adopt text nodes via hydration markers
       - Effects are set up to update adopted nodes when signals change
       - Event handlers are attached to adopted elements *)
    let _node = component () in
    ()
  ) in

  (* Clean up hydration markers from the DOM *)
  Hydration.remove_hydration_markers root;

  (* Disable hydration mode *)
  Hydration.end_hydration ();

  dispose

(** Get hydration data embedded in the page by the server.
    
    The server embeds data as:
    <script>window.__SOLID_ML_DATA__ = {...};</script>
    
    Returns None if no data is present. *)
let get_hydration_data () =
  Js.Nullable.toOption (Dom.get_hydration_data ())

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

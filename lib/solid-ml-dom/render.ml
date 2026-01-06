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
  let (_, dispose) = Reactive_core.create_root (fun () ->
    let node = component () in
    Html.append_to_element root node
  ) in
  dispose

(** {1 Hydration} *)

(** Hydration marker format from solid-ml-html:
    <!--hk:N-->content<!--/hk-->
    
    Where N is the hydration key (integer). *)

(** Find a text node following a hydration marker comment.
    Walks child nodes looking for pattern: Comment(hk:N) -> Text -> Comment(/hk) *)
let find_hydration_text_nodes root =
  let markers = Hashtbl.create 16 in
  
  let rec walk_children (parent : Dom.element) =
    let children = Dom.get_child_nodes parent in
    let len = Array.length children in
    let i = ref 0 in
    while !i < len do
      let node = children.(!i) in
      if Dom.is_comment node then begin
        let comment = Dom.comment_of_node node in
        let data = Dom.comment_data comment in
        (* Check if this is a start marker: hk:N *)
        if String.length data > 3 && String.sub data 0 3 = "hk:" then begin
          let key_str = String.sub data 3 (String.length data - 3) in
          match int_of_string_opt key_str with
          | Some key ->
            (* Next node should be the text content *)
            if !i + 1 < len then begin
              let next = children.(!i + 1) in
              if Dom.is_text next then begin
                let text_node = Dom.text_of_node next in
                Hashtbl.add markers key text_node
              end
            end
          | None -> ()
        end
      end else if Dom.is_element node then begin
        (* Recurse into child elements *)
        walk_children (Dom.element_of_node node)
      end;
      incr i
    done
  in
  
  walk_children root;
  markers

(** Hydrate server-rendered HTML.
    
    This function "adopts" existing DOM nodes rendered by the server and
    attaches reactive bindings without re-rendering.
    
    For hydration to work correctly:
    1. The component must produce the same structure as the server render
    2. Reactive text nodes are matched via hydration markers (<!--hk:N-->)
    3. Event handlers are attached to existing elements
    
    Current limitations:
    - Only reactive text nodes (signal_text) are hydrated via markers
    - Element structure must match exactly
    - No support for streaming/progressive hydration
    
    @param root The DOM element containing server-rendered HTML
    @param component The component function (must match server render) *)
let hydrate root component =
  (* Find existing hydration markers and their text nodes *)
  let markers = find_hydration_text_nodes root in
  
  (* Store markers for reactive text to find *)
  (* This is a simplified approach - a full implementation would
     walk the component tree and DOM tree simultaneously *)
  let _ = markers in
  
  let (_, dispose) = Reactive_core.create_root (fun () ->
    (* Run the component to set up the reactive graph.
       
       In a full implementation, we would:
       1. Walk component output and existing DOM simultaneously
       2. For each element, attach event handlers to existing DOM element
       3. For each reactive text, connect to existing text node via marker
       4. Skip creating new DOM nodes entirely
       
       Current simplified approach:
       - Runs component (which creates signals/effects)
       - Effects will try to update DOM
       - For text nodes, they create new nodes (not ideal)
       
       TODO: Implement proper DOM walking hydration *)
    let _node = component () in
    ()
  ) in
  
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

(** Suspense boundaries for async loading states.
    
    Suspense provides a way to show fallback content while waiting for
    async resources to load. When a resource is read inside a Suspense
    boundary and is still loading, the boundary shows its fallback.
    Once all resources are ready, it shows the actual content.
    
    This uses a counter-based approach similar to SolidJS:
    - Each loading resource increments a counter during render
    - Fallback is shown when counter > 0
    - Content is shown when counter = 0
    - When resources resolve, the reactive system re-renders with fresh state
    
    {[
      Suspense.boundary
        ~fallback:(fun () -> Html.text "Loading...")
        (fun () ->
          let user = Resource.read_suspense ~default:empty_user user_resource in
          render_user user
        )
    ]}
    
    Note: Suspense does NOT handle errors. Wrap in ErrorBoundary for error handling:
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset -> Html.text ("Error: " ^ error))
        (fun () ->
          Suspense.boundary ~fallback:spinner (fun () ->
            let data = Resource.read_suspense ~default user_resource in
            render data
          )
        )
    ]}
*)

module R = Reactive.R

(** {1 Types} *)

(** Internal state for a Suspense boundary *)
type suspense_state = {
  mutable count : int;
  mutable in_fallback : bool;
  mutable registered_ids : int list;
}

(** Sentinel value for "no suspense context" *)
let no_context_sentinel = {
  count = -1;
  in_fallback = false;
  registered_ids = [];
}

(** Context for passing Suspense state down the tree *)
let suspense_context : suspense_state Context.t = 
  Context.create no_context_sentinel

(** {1 Registration} *)

(** Increment the pending count (called when a resource is loading) *)
let increment state resource_id =
  if not (List.mem resource_id state.registered_ids) then begin
    state.registered_ids <- resource_id :: state.registered_ids;
    state.count <- state.count + 1;
    if state.count = 1 then
      state.in_fallback <- true
  end

(** Check if we're currently inside a valid Suspense boundary *)
let has_boundary () =
  let state = Context.use suspense_context in
  state.count >= 0

(** Check if currently showing fallback content *)
let is_in_fallback () =
  let state = Context.use suspense_context in
  state.in_fallback

(** Get the current Suspense state, if inside a boundary *)
let get_state () =
  let state = Context.use suspense_context in
  if state.count >= 0 then Some state else None

(** {1 Boundary Component} *)

(** Create a Suspense boundary.
    
    Shows [fallback] while any resources inside are loading.
    Shows [children] when all resources are ready.
    
    @param fallback Function that renders loading state
    @param children Function that renders content (may read resources) *)
let boundary ~fallback children =
  (* Create our suspense state - fresh for each render *)
  let state = {
    count = 0;
    in_fallback = false;
    registered_ids = [];
  } in
  
  (* Provide context and render *)
  Context.provide suspense_context state (fun () ->
    (* Render children first to discover resources.
       Resources that are loading will increment the counter.
       Note: On re-render, resources will re-register with this fresh state. *)
    let initial_result = children () in
    
    (* If we discovered loading resources, switch to fallback *)
    if state.count > 0 then begin
      state.in_fallback <- true;
      fallback ()
    end else
      initial_result
  )

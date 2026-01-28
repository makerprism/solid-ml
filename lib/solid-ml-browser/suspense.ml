(** Suspense boundaries for async loading states (browser version).
    
    Suspense provides a way to show fallback content while waiting for
    async resources to load. This matches SolidJS's Suspense behavior.
    
    {[
      Suspense.boundary
        ~fallback:(fun () -> Html.text "Loading...")
        (fun () ->
          let user = Resource.read_suspense ~default:empty_user user_resource in
          render_user user
        )
    ]}
*)

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
let suspense_context : suspense_state Reactive_core.context = 
  Reactive_core.create_context no_context_sentinel

(** {1 Registration} *)

(** Increment the pending count (called when a resource starts loading) *)
let increment state resource_id =
  if not (List.mem resource_id state.registered_ids) then begin
    state.registered_ids <- resource_id :: state.registered_ids;
    state.count <- state.count + 1;
    if state.count = 1 then
      state.in_fallback <- true
  end

(** Check if we're currently inside a valid Suspense boundary *)
let has_boundary () =
  let state = Reactive_core.use_context suspense_context in
  state.count >= 0

(** Get the current Suspense state, if inside a boundary *)
let get_state () =
  let state = Reactive_core.use_context suspense_context in
  if state.count >= 0 then Some state else None

(** {1 Boundary Component} *)

(** Create a Suspense boundary.
    
    Shows [fallback] while any resources inside are loading.
    Shows [children] when all resources are ready. *)
let boundary ~fallback children =
  (* Create our suspense state - fresh for each render *)
  let state = {
    count = 0;
    in_fallback = false;
    registered_ids = [];
  } in
  
  (* Provide context and render *)
  Reactive_core.provide_context suspense_context state (fun () ->
    (* Render children first to discover resources.
       Resources that are loading will increment the counter. *)
    let initial_result = children () in
    
    (* If we discovered loading resources, switch to fallback *)
    if state.count > 0 then begin
      state.in_fallback <- true;
      fallback ()
    end else
      initial_result
  )

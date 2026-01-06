(** Suspense boundaries for async loading states.
    
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
    
    {2 How it works}
    
    - Each Suspense boundary maintains a counter of pending resources
    - When [Resource.read_suspense] is called on a loading resource, the counter increments
    - Fallback is shown when counter > 0
    - When resources resolve, the reactive system re-renders with fresh state
    
    {2 Error handling}
    
    Suspense does NOT handle errors. When a resource errors, [read_suspense] raises
    an exception. Use {!ErrorBoundary} to catch errors:
    
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
    
    {2 SSR behavior}
    
    During server-side rendering, Suspense boundaries render their fallback
    if any resources are still loading. The client will hydrate and fetch
    the actual data.
*)

(** {1 Types} *)

(** Internal suspense state (opaque) *)
type suspense_state

(** {1 Context} *)

(** The Suspense context. Used by Resource to register with boundaries. *)
val suspense_context : suspense_state Context.t

(** {1 Registration (for Resource module)} *)

(** Increment the pending count. Call when a resource starts loading. *)
val increment : suspense_state -> unit

(** Check if we're inside a valid Suspense boundary. *)
val has_boundary : unit -> bool

(** Check if currently showing fallback content. *)
val is_in_fallback : unit -> bool

(** Get the current Suspense state, if inside a boundary. *)
val get_state : unit -> suspense_state option

(** {1 Boundary Component} *)

(** Create a Suspense boundary.
    
    Shows [fallback] while any resources read inside are loading.
    Shows [children] when all resources are ready.
    
    {[
      Suspense.boundary
        ~fallback:(fun () -> Html.div [] [Html.text "Loading..."])
        (fun () ->
          let user = Resource.read_suspense ~default:User.empty user_resource in
          User_card.make user
        )
    ]}
    
    @param fallback Function that renders the loading state
    @param children Function that renders the content *)
val boundary : fallback:(unit -> 'a) -> (unit -> 'a) -> 'a

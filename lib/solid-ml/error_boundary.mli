(** Error boundaries for catching and handling errors.
    
    ErrorBoundary catches exceptions thrown during rendering and displays
    a fallback UI. This matches SolidJS's ErrorBoundary behavior.
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset ->
          Html.div [] [
            Html.text ("Error: " ^ error);
            Html.button ~on_click:(fun _ -> reset ()) [Html.text "Retry"]
          ])
        (fun () ->
          let data = Resource.read_suspense ~default user_resource in
          render data
        )
    ]}
    
    {2 With Suspense}
    
    ErrorBoundary is typically used with Suspense to handle both loading
    and error states:
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset -> error_view error reset)
        (fun () ->
          Suspense.boundary
            ~fallback:(fun () -> loading_spinner ())
            (fun () ->
              let data = Resource.read_suspense ~default resource in
              render_data data
            )
        )
    ]}
    
    {2 What is caught}
    
    ErrorBoundary catches:
    - Exceptions from [Resource.read_suspense] when resource is in error state
    - Any other exceptions thrown during rendering
    - Exceptions from effects created during rendering
    
    ErrorBoundary does NOT catch:
    - Errors in event handlers (use try/catch in the handler)
    - Errors in setTimeout/setInterval callbacks
    - Errors that occur after initial render (use effect error handling)
*)

(** {1 Error Boundary} *)

(** Create an error boundary.
    
    Catches any exception thrown by [children] and renders [fallback] instead.
    
    {[
      ErrorBoundary.make
        ~fallback:(fun ~error ~reset ->
          Html.div [] [
            Html.p [] [Html.text error];
            Html.button ~on_click:(fun _ -> reset ()) [Html.text "Try again"]
          ])
        (fun () ->
          risky_render ()
        )
    ]}
    
    @param fallback Function receiving [~error] message and [~reset] function
    @param children Function that renders the normal content
    @return The rendered content, or fallback if an error occurred *)
val make : fallback:(error:string -> reset:(unit -> unit) -> 'a) -> (unit -> 'a) -> 'a

(** Simpler error boundary without reset capability.
    
    {[
      ErrorBoundary.make_simple
        ~fallback:(fun error -> Html.text ("Error: " ^ error))
        (fun () -> risky_render ())
    ]}
    
    @param fallback Function receiving the error message
    @param children Function that renders the normal content *)
val make_simple : fallback:(string -> 'a) -> (unit -> 'a) -> 'a

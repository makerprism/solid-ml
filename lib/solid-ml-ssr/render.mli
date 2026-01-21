(** Server-side rendering utilities.

    This module provides functions to render solid-ml components to HTML strings
    for server-side rendering (SSR).

    {[
      let page () =
        Html.(
          div ~class_:"container" ~children:[
            h1 ~children:[text "Welcome"] ();
            p ~children:[text "Hello, World!"] ()
          ] ()
        )

      let html_string = Render.to_string page
    ]}
*)

(** Render a component function to an HTML string.
    
    The component is executed within a reactive root that is immediately disposed,
    capturing the initial state of all signals.
    
    Hydration markers are generated for reactive elements.
    
    {[
      let html = Render.to_string (fun () ->
        Html.(div ~children:[text "Hello"] ())
      )
      (* Returns: <div>Hello</div> *)
    ]}
*)
val to_string : (unit -> Html.node) -> string

(** Render a component using a strict runtime token.

    The component receives the token for creating strict signals/effects.
*)
val to_string_strict : Solid_ml.Runtime.token -> (Solid_ml.Runtime.token -> Html.node) -> string

(** Render a component to a complete HTML document.
    
    Includes DOCTYPE declaration.
    
    {[
      let html = Render.to_document (fun () ->
        Html.(html ~children:[
          head ~children:[title ~children:[text "My App"] ()] ();
          body ~children:[text "Hello"] ()
        ] ())
      )
    ]}
*)
val to_document : (unit -> Html.node) -> string

(** Render a document using a strict runtime token.

    The component receives the token for creating strict signals/effects.
*)
val to_document_strict : Solid_ml.Runtime.token -> (Solid_ml.Runtime.token -> Html.node) -> string

(** Get the hydration data as a JSON string.
    
    This should be embedded in the HTML as a script tag for client-side hydration.
    
    {[
      let html = Render.to_string my_component in
      let hydration = Render.get_hydration_script () in
      (* Include hydration script in page *)
    ]}
*)
val get_hydration_script : unit -> string

(** Reset the hydration state.
    
    Call this between renders to reset hydration key counter.
*)
val reset : unit -> unit

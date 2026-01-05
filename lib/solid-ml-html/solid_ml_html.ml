(** solid-ml-html: Server-side rendering for solid-ml.

    This package provides HTML element functions and rendering utilities
    for server-side rendering (SSR) of solid-ml components.

    {[
      open Solid_ml_html

      let my_page () =
        Html.(
          div ~class_:"container" ~children:[
            h1 ~children:[text "Welcome"] ();
            p ~children:[text "This is server-rendered HTML"] ()
          ] ()
        )

      let html_string = Render.to_string my_page
    ]}
*)

module Html = Html
module Render = Render

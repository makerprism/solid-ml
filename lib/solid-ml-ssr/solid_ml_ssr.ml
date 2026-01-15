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

module Env = struct
  module Signal = struct
    type 'a t = 'a Solid_ml.Signal.t

    let create ?equals = Solid_ml.Signal.create ?equals
    let get = Solid_ml.Signal.get
    let peek = Solid_ml.Signal.peek
    let update = Solid_ml.Signal.update
  end

  type 'a signal = 'a Signal.t

  module Html = Html
  module Effect = Solid_ml.Effect
  module Owner = Solid_ml.Owner
end

module _ : Solid_ml.Component.TEMPLATE_ENV = Env

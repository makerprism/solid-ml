(** solid-ml-ssr: Server-side rendering for solid-ml.

    This package provides HTML element functions and rendering utilities
    for server-side rendering (SSR) of solid-ml components.

    {[
      open Solid_ml_ssr

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
module State = State
module Resource_state = Resource_state
module Router_components = Router_components
module Router_resource = Router_resource

module Env = struct
  module Signal = struct
    type 'a t = 'a Solid_ml.Signal.t

    let create ?equals = Solid_ml.Signal.Unsafe.create ?equals
    let get = Solid_ml.Signal.get
    let peek = Solid_ml.Signal.peek
    let update = Solid_ml.Signal.update
  end

  type 'a signal = 'a Signal.t

  module Html = struct
    include Html
    module Internal_template = Html.Internal_template
  end

  module Tpl = Solid_ml_template_runtime.Tpl
  module Effect = struct
    let create = Solid_ml.Effect.Unsafe.create
    let create_with_cleanup = Solid_ml.Effect.Unsafe.create_with_cleanup
  end

  module Owner = struct
    let on_cleanup = Solid_ml.Owner.on_cleanup
    let on_mount = Solid_ml.Owner.on_mount
    let run_with_root = Solid_ml.Owner.Unsafe.run_with_root
  end

  module Suspense = Solid_ml.Suspense

  module ErrorBoundary = struct
    let make = Solid_ml.ErrorBoundary.Unsafe.make
  end

  module Transition = Solid_ml.Transition
end

module _ : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV = Env

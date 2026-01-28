(** solid-ml-browser: Browser-side reactive framework for solid-ml.
    
    This library provides DOM rendering and hydration for solid-ml components,
    compiled to JavaScript via Melange.
    
    It uses the shared reactive core (solid-ml-internal) with a browser-specific
    backend that uses global refs (safe in single-threaded JS) and logs errors
    to the console.
    
    {1 Basic Usage}
    
    {[
      open Solid_ml_browser
      open Reactive
      
      let counter () =
        let count, set_count = Signal.create 0 in
        Html.(
          div ~children:[
            p ~children:[Reactive.reactive_text count] ();
            button 
              ~onclick:(fun _ -> Signal.update count succ)
              ~children:[text "+"] 
              ();
          ] ()
        )
      
      let () =
        match Dom.get_element_by_id (Dom.document ()) "app" with
        | Some root -> ignore (Render.render root counter)
        | None -> Dom.error "No #app element found"
    ]}
    
    {1 Modules}
*)

(** Low-level DOM bindings *)
module Dom = Dom

(** HTML element creation with event handler support *)
module Html = Html

(** Reactive DOM primitives and re-exported core types (Signal, Effect, Memo, etc.) *)
module Reactive = Reactive

(** Reactive signals with automatic dependency tracking *)
module Signal = Reactive.Signal

(** Side-effecting computations *)
module Effect = Reactive.Effect

(** Cached derived values *)
module Memo = Reactive.Memo

(** Batched signal updates *)
module Batch = Reactive.Batch

(** Ownership and disposal tracking *)
module Owner = Reactive.Owner

(** Component context for passing values down the tree *)
module Context = Reactive.Context

(** Event handling utilities *)
module Event = Event
module Event_replay = Event_replay

(** Rendering and hydration *)
module Render = Render
module State = State

(** Navigation helpers for SPA-style links *)
module Navigation = Navigation


(** Browser-optimized reactive core - use Reactive module for higher-level API *)
module Reactive_core = Reactive_core

(** Browser router with History API integration *)
module Router = Router

(** Async resource with loading/error/ready states *)
module Resource = Resource

(** Async primitive for Promise-based data with Suspense integration *)
module Async = Async

(** Actions for mutations with cache revalidation *)
module Action = Action

(** Lens-based store for nested reactive state *)
module Store = Store

(** Suspense boundaries for async loading states *)
module Suspense = Suspense

(** Error boundaries for catching errors *)
module ErrorBoundary = Error_boundary

(** Transition scheduling for deferred updates *)
module Transition = Transition

(** Deferred signals (createDeferred parity) *)
module Deferred = Deferred

(** Generate unique IDs for hydration *)
module Unique_id = Unique_id

(** For component - keyed list rendering by item identity *)
module For = For

(** Index component - position-keyed list rendering *)
module Index = Index

module Env = struct
  type 'a signal = 'a Reactive_core.signal

  module Signal = struct
    type 'a t = 'a signal

    let create ?equals initial =
      let s = Reactive_core.create_signal ?equals initial in
      (s, fun v -> Reactive_core.set_signal s v)

    let get = Reactive_core.get_signal
    let peek = Reactive_core.peek_signal

    let update s f =
      Reactive_core.update_signal s f
  end

  module Html = struct
    include Html
    module Internal_template = Html.Internal_template
  end

  module Tpl = Solid_ml_template_runtime.Tpl

  module Effect = struct
    let create = Reactive.Effect.create
    let create_with_cleanup = Reactive.Effect.create_with_cleanup
  end

  module Owner = struct
    let on_cleanup = Reactive.Owner.on_cleanup
    let on_mount = Reactive.Owner.on_mount
    let run_with_root = Reactive_core.run_with_root
  end

  module Suspense = Suspense
  module ErrorBoundary = ErrorBoundary
  module Transition = Transition
end

module _ : Solid_ml_template_runtime.Env_intf.TEMPLATE_ENV = Env

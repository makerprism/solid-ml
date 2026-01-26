(** solid-ml: Fine-grained reactivity for OCaml.
    
    A reactive programming framework inspired by SolidJS, providing
    signals, effects, memos, and a component model with automatic
    dependency tracking.
    
    {[
      open Solid_ml
      
      let counter () =
        let count, set_count = Signal.create 0 in
        
        Effect.create (fun () ->
          print_endline ("Count: " ^ string_of_int (Signal.get count))
        );
        
        set_count 1;  (* prints "Count: 1" *)
        set_count 2   (* prints "Count: 2" *)
    ]}
    
    For server-side rendering with Dream or other frameworks,
    wrap each request in [Runtime.run]:
    
    {[
      let handler _req =
        Runtime.run (fun () ->
          let html = Render.to_string my_component in
          Dream.html html
        )
    ]}
    
    {1 Architecture}
    
    The reactive system is based on SolidJS's design:
    
    - {b Signals} hold reactive values with bidirectional tracking
    - {b Effects} are side-effecting computations that auto-track dependencies
    - {b Memos} are cached derived values (lazy computation)
    - {b Owners} track lifecycle for automatic cleanup
    - {b Contexts} pass values down the component tree
    
    All state is stored per-domain using Domain-local storage,
    making it safe for concurrent server-side rendering.
*)

(** Core reactive system (usually not used directly) *)
module Reactive = Reactive

(** Runtime management for reactive contexts *)
module Runtime = Runtime

(** Token-scoped helper API for strict usage *)
module Scoped = Scoped

(** Reactive signals with automatic dependency tracking *)
module Signal = Signal

(** Side-effecting computations *)
module Effect = Effect

(** Cached derived values *)
module Memo = Memo

(** Batched signal updates *)
module Batch = Batch

(** Ownership and disposal tracking *)
module Owner = Owner

(** Component context for passing values down the tree *)
module Context = Context

(** Suspense boundaries for async loading states *)
module Suspense = Suspense

(** Error boundaries for catching errors *)
module ErrorBoundary = Error_boundary

(** Transition scheduling for deferred updates *)
module Transition = Transition

(** Generate unique IDs for SSR hydration *)
module Unique_id = Unique_id

(** Reactive store with nested reactivity *)
module Store = Store

(** Async resource with loading/error/ready states *)
module Resource = Resource

(** Html interface for unified SSR/browser components *)
module Html_intf = Html_intf

(** Component abstraction for shared SSR/browser code *)
module Component = Component

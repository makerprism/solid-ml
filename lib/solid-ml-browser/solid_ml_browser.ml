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
            p ~children:[Reactive.text count] ();
            button 
              ~onclick:(fun _ -> Signal.update count succ)
              ~children:[text "+"] 
              ();
          ] ()
        )
      
      let () =
        match Dom.get_element_by_id Dom.document "app" with
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

(** Event handling utilities *)
module Event = Event

(** Rendering and hydration *)
module Render = Render

(** Browser-optimized reactive core - use Reactive module for higher-level API *)
module Reactive_core = Reactive_core

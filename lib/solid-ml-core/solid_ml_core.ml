(** solid-ml-core: Shared reactive primitives for solid-ml.
    
    This package provides a functor-based reactive system that can be
    instantiated with different backends for server (OCaml 5 DLS) and
    browser (global refs via Melange).
    
    {1 Usage}
    
    {[
      (* Create a reactive system with global backend *)
      module R = Reactive_functor.Make(Backend.Global)
      
      (* Use it *)
      R.run (fun () ->
        let signal = R.create_signal (Obj.repr 0) in
        ...
      )
    ]}
    
    {1 Modules}
*)

(** Core type definitions *)
module Types = Types

(** Backend module type and implementations *)
module Backend = Backend

(** Functor to create reactive system *)
module Reactive_functor = Reactive_functor

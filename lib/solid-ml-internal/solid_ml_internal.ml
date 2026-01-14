(** solid-ml-internal: Shared reactive internals.
    
    DO NOT use this package directly.
    Use solid-ml (server) or solid-ml-browser (browser) instead.
    
    This package provides a functor-based reactive system that can be
    instantiated with different backends for server (OCaml 5 DLS) and
    browser (global refs via Melange).
*)

(** Internal type definitions (uses Obj.t for type erasure) *)
module Types = Types

(** Backend module type and implementations *)
module Backend = Backend

(** Functor to create reactive system *)
module Reactive_functor = Reactive_functor

(** Route parameter filters (shared between server and browser) *)
module Filter = Filter

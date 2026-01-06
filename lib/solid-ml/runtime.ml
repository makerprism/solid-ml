(** Execution runtime that holds all reactive state.
    
    Each render/request should create its own runtime to ensure
    thread safety. All reactive operations happen within a runtime context.
    
    Uses Domain-local storage (OCaml 5) for safe parallel execution
    across domains.
    
    Note: This module is a thin wrapper around Reactive for backwards
    compatibility. The actual implementation is in Reactive.
*)

(** Runtime type - use opaque to users *)
type t = Reactive.runtime

(** Owner type for cleanup tracking *)
type owner = Reactive.owner

(** Get the current runtime, raising if none is active *)
let get_current () = Reactive.get_runtime ()

(** Get the current runtime if one is active *)
let get_current_opt () = Reactive.get_runtime_opt ()

(** Create a new runtime and run function within it.
    
    This is the main entry point for reactive code.
    Each call creates isolated reactive state.
    
    Example:
    {[
      Runtime.run (fun () ->
        let count, set = Signal.create 0 in
        Effect.create (fun () ->
          print_int (Signal.get count)
        );
        set 1
      )
    ]} *)
let run = Reactive.run

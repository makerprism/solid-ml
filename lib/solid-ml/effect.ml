(** Reactive effects with automatic dependency tracking.
    
    Effects are computations that re-run when their dependencies change.
    They are used for side effects like DOM updates, logging, etc.
*)

module Internal = Solid_ml_internal
module R = Reactive.R

(** Create an effect that runs when dependencies change.
    
    The effect function is called immediately, and then re-called
    whenever any signal read during execution changes. *)
let create = R.create_effect

(** Create an effect with a cleanup function.
    
    The effect function should return a cleanup function that will
    be called before the next execution and when the effect is disposed. *)
let create_with_cleanup = R.create_effect_with_cleanup

(** Execute a function without tracking dependencies. *)
let untrack = R.untrack

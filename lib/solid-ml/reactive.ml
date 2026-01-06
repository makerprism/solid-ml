(** Core reactive system using the shared functor with DLS backend.
    
    This module provides the server-side reactive primitives with
    thread-safe isolation via Domain-local storage (DLS). Each domain
    gets its own independent reactive runtime.
    
    The implementation delegates to the shared core (solid-ml-core)
    which contains all the reactive algorithms. This module just:
    1. Instantiates the functor with the DLS backend
    2. Provides typed wrappers for the Obj.t-based internal API
*)

(** {1 Re-export Types} *)

(** State of a computation *)
type computation_state = Solid_ml_core.Types.computation_state =
  | Clean
  | Stale
  | Pending

(** Source kind for dependency tracking *)
type source_kind = Solid_ml_core.Types.source_kind =
  | Signal_source
  | Memo_source

(** A signal holds a reactive value with observers.
    
    Note: Internally uses Obj.t for type erasure, but we expose
    a polymorphic interface for type safety. *)
type 'a signal_state = {
  mutable value: 'a;
  mutable observers: computation array;
  mutable observer_slots: int array;
  mutable observers_len: int;
  comparator: ('a -> 'a -> bool) option;
}

(** Owner node for cleanup hierarchy *)
and owner = Solid_ml_core.Types.owner = {
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  mutable child_owners: owner list;
}

(** A computation (effect or memo) *)
and computation = Solid_ml_core.Types.computation = {
  mutable fn: (Obj.t -> Obj.t) option;
  mutable state: computation_state;
  mutable sources: Obj.t array;
  mutable source_slots: int array;
  mutable source_kinds: source_kind array;
  mutable sources_len: int;
  mutable value: Obj.t;
  mutable updated_at: int;
  pure: bool;
  mutable user: bool;
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  mutable memo_observers: computation array option;
  mutable memo_observer_slots: int array option;
  mutable memo_observers_len: int;
  mutable memo_comparator: (Obj.t -> Obj.t -> bool) option;
}

(** Runtime state for a reactive context *)
type runtime = Solid_ml_core.Types.runtime = {
  mutable listener: computation option;
  mutable owner: owner option;
  mutable updates: computation list;
  mutable effects: computation list;
  mutable exec_count: int;
  mutable in_update: bool;
}

(** {1 Instantiate Functor with DLS Backend} *)

module R = Solid_ml_core.Reactive_functor.Make(Solid_ml_core.Backend.DLS)

(** {1 Public API} *)

(** Get current runtime *)
let get_runtime = R.get_runtime

(** Get current runtime if any *)
let get_runtime_opt = R.get_runtime_opt

(** Create a new runtime *)
let create_runtime = Solid_ml_core.Types.create_runtime

(** Run a function within a reactive runtime *)
let run = R.run

(** Create a root owner for cleanup *)
let create_root = R.create_root

(** Register a cleanup function *)
let on_cleanup = R.on_cleanup

(** Read without tracking *)
let untrack = R.untrack

(** {1 Signal Operations (Type-Safe Wrappers)} *)

(** Read a signal with tracking.
    Wraps the Obj.t-based internal function with type safety. *)
let read_signal : 'a. 'a signal_state -> 'a = fun signal ->
  (* Cast to internal type and read *)
  let internal : Solid_ml_core.Types.signal_state = Obj.magic signal in
  Obj.magic (R.read_signal internal)

(** Write to a signal, notifying observers *)
let write_signal : 'a. 'a signal_state -> 'a -> unit = fun signal value ->
  let internal : Solid_ml_core.Types.signal_state = Obj.magic signal in
  R.write_signal internal (Obj.repr value)

(** {1 Computation Operations} *)

(** Create a new computation *)
let create_computation = R.create_computation

(** Clean up a computation *)
let clean_node = R.clean_node

(** Execute a computation *)
let run_computation = R.run_computation

(** Process a computation *)
let run_top = R.run_top

(** Execute within an update cycle *)
let run_updates = R.run_updates

(** {1 Memo Support} *)

(** Mark downstream nodes as pending (for memo change propagation) *)
let look_upstream (node: computation) =
  node.state <- Clean

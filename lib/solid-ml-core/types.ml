(** Core types for the reactive system.
    
    These types are shared between server and browser implementations.
    The key insight is that all reactive values are stored as Obj.t
    for type erasure, allowing uniform handling of signals and memos.
*)

(** State of a computation (effect or memo) *)
type computation_state = 
  | Clean   (** Up-to-date, no recomputation needed *)
  | Stale   (** Definitely needs recomputation *)
  | Pending (** Maybe needs recomputation (upstream might be stale) *)

(** Tag to distinguish signal sources from memo sources in cleanup *)
type source_kind = 
  | Signal_source  (** Source is a signal_state *)
  | Memo_source    (** Source is a computation (memo) *)

(** A signal holds a reactive value with observers.
    
    Uses dynamic arrays (observers/observer_slots) with a length field
    for O(1) swap-and-pop removal. *)
type signal_state = {
  mutable value: Obj.t;
  mutable observers: computation array;
  mutable observer_slots: int array;
  mutable observers_len: int;
  comparator: (Obj.t -> Obj.t -> bool) option;
}

(** Owner node for cleanup hierarchy.
    
    Owners form a tree structure for managing component lifecycles.
    When an owner is disposed, all its children and cleanups are run. *)
and owner = {
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  mutable child_owners: owner list;
}

(** A computation (effect or memo).
    
    Computations can be:
    - Effects (pure=false): Side effects that run when dependencies change
    - Memos (pure=true): Cached derived values with optional observers
    
    The bidirectional links (sources <-> observers) allow O(1) cleanup
    when a computation is disposed or re-run. *)
and computation = {
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
  
  (* Owner fields (computation extends owner) *)
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  
  (* Memo-specific: if this is a memo, it can also be observed *)
  mutable memo_observers: computation array option;
  mutable memo_observer_slots: int array option;
  mutable memo_observers_len: int;
  mutable memo_comparator: (Obj.t -> Obj.t -> bool) option;
}

(** Runtime state for a single reactive context.
    
    Each Runtime.run creates a fresh runtime on the server.
    On browser, there's effectively one global runtime. *)
type runtime = {
  mutable listener: computation option;
  mutable owner: owner option;
  mutable updates: computation list;
  mutable effects: computation list;
  mutable exec_count: int;
  mutable in_update: bool;
}

(** Create a fresh runtime *)
let create_runtime () = {
  listener = None;
  owner = None;
  updates = [];
  effects = [];
  exec_count = 0;
  in_update = false;
}

(** Create an empty computation (for initialization) *)
let empty_computation () = {
  fn = None;
  state = Clean;
  sources = [||];
  source_slots = [||];
  source_kinds = [||];
  sources_len = 0;
  value = Obj.repr ();
  updated_at = 0;
  pure = false;
  user = false;
  owned = [];
  cleanups = [];
  owner = None;
  context = [];
  memo_observers = None;
  memo_observer_slots = None;
  memo_observers_len = 0;
  memo_comparator = None;
}

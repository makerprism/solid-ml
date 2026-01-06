(** Internal types for the reactive system.
    
    These types use Obj.t for type erasure, allowing uniform handling
    of signals and memos in the dependency graph. The platform-specific
    packages (solid-ml, solid-ml-dom) provide type-safe wrappers.
    
    DO NOT use this module directly - use solid-ml or solid-ml-dom instead.
*)

(** {1 Computation State} *)

type computation_state = 
  | Clean   (** Up-to-date, no recomputation needed *)
  | Stale   (** Definitely needs recomputation *)
  | Pending (** Maybe needs recomputation (upstream might be stale) *)

(** {1 Source Kind} *)

type source_kind = 
  | Signal_source
  | Memo_source

(** {1 Signal State} *)

(** Internal signal representation - stores value as Obj.t *)
type signal_state = {
  mutable value: Obj.t;
  mutable observers: computation array;
  mutable observer_slots: int array;
  mutable observers_len: int;
  comparator: (Obj.t -> Obj.t -> bool) option;
}

(** {1 Owner} *)

and owner = {
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  mutable child_owners: owner list;
}

(** {1 Computation} *)

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
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  mutable child_owners: owner list;  (* Roots created inside this computation *)
  mutable memo_observers: computation array option;
  mutable memo_observer_slots: int array option;
  mutable memo_observers_len: int;
  mutable memo_comparator: (Obj.t -> Obj.t -> bool) option;
}

(** {1 Runtime} *)

(** Initial capacity for update/effect queues.
    Sized for typical benchmark operations (100 updates for every-10th-row). *)
let initial_queue_capacity = 128

type runtime = {
  mutable listener: computation option;
  mutable owner: owner option;
  (* Mutable array queues instead of lists - avoids allocation on every push *)
  mutable updates: computation array;
  mutable updates_len: int;
  mutable effects: computation array;
  mutable effects_len: int;
  mutable exec_count: int;
  mutable in_update: bool;
}

(** {1 Constructors} *)

(** Singleton dummy computation for array padding.
    Avoids allocating a fresh 19-field record on every array resize. *)
let dummy_computation : computation = {
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
  child_owners = [];
  memo_observers = None;
  memo_observer_slots = None;
  memo_observers_len = 0;
  memo_comparator = None;
}

let create_runtime () = {
  listener = None;
  owner = None;
  updates = Array.make initial_queue_capacity dummy_computation;
  updates_len = 0;
  effects = Array.make initial_queue_capacity dummy_computation;
  effects_len = 0;
  exec_count = 0;
  in_update = false;
}

(** Create a fresh computation. Use dummy_computation for array padding instead. *)
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
  child_owners = [];
  memo_observers = None;
  memo_observer_slots = None;
  memo_observers_len = 0;
  memo_comparator = None;
}

(** {1 Typed Signal}
    
    Phantom type wrapper for type-safe signals.
    The type parameter 'a only exists at compile time. *)

type 'a signal = signal_state

let create_typed_signal (type a) ?(equals : (a -> a -> bool) option) (initial : a) : a signal =
  let comparator = match equals with
    | Some eq -> Some (fun a b -> eq (Obj.obj a) (Obj.obj b))
    | None -> None
  in
  {
    value = Obj.repr initial;
    observers = [||];
    observer_slots = [||];
    observers_len = 0;
    comparator;
  }

let get_signal_value (type a) (s : a signal) : a = Obj.obj s.value
let set_signal_value (type a) (s : a signal) (v : a) : unit = s.value <- Obj.repr v
let signal_to_internal (s : 'a signal) : signal_state = s

(** {1 Typed Memo}
    
    Wraps a computation with a typed cache for efficient access. *)

type 'a memo = {
  comp: computation;
  mutable cached: 'a;
  mutable has_cached: bool;
  equals: 'a -> 'a -> bool;
}

let get_memo_value (type a) (m : a memo) : a = m.cached
let set_memo_value (type a) (m : a memo) (v : a) : unit = 
  m.cached <- v;
  m.has_cached <- true
let memo_has_value (m : _ memo) : bool = m.has_cached
let memo_to_computation (m : _ memo) : computation = m.comp
let memo_equals (type a) (m : a memo) (a : a) (b : a) : bool = m.equals a b

let create_typed_memo (type a) ~(equals : a -> a -> bool) ~(comp : computation) : a memo = {
  comp;
  cached = Obj.magic ();  (* Will be set before first read *)
  has_cached = false;
  equals;
}

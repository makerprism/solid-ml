(** Reactive signals with automatic dependency tracking.
    
    Signals are the core primitive of solid-ml's reactivity system.
    When you read a signal inside an effect or memo, that computation
    automatically subscribes to the signal and re-runs when it changes.
    
    {[
      let count, set_count = Signal.create 0
      
      (* Reading tracks dependency *)
      Effect.create (fun () ->
        print_endline ("Count: " ^ string_of_int (Signal.get count))
      )
      
      (* Writing notifies all subscribers *)
      set_count 1  (* prints "Count: 1" *)
    ]}
    
    {b Important}: Signals should not be shared across runtimes or domains.
    Each signal belongs to the runtime in which it was created. Sharing
    signals leads to undefined behavior as subscribers from one runtime
    may be notified in another runtime's context.
*)

(** A reactive value that tracks its dependents. *)
type 'a t = 'a Reactive.signal

(** Create a new signal with an initial value.
    Returns a tuple of (signal, setter function).
    
    By default, uses structural equality [(=)] to skip updates when
    the new value equals the current value.
    
    {[
      let count, set_count = Signal.create 0
      set_count 0  (* No update - same value *)
      set_count 1  (* Updates and notifies *)
    ]}
*)
val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)

(** Create a signal with a custom equality function.
    
    {[
      (* Only update when list length changes *)
        let items, set_items = Signal.create_eq
          ~equals:(fun a b -> List.length a = List.length b) 
          []
    ]}
*)
val create_eq : equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)

(** Create a signal using physical equality [(==)] for comparisons.
    
    Use this for:
    - Signals holding mutable values (where structural equality is expensive)
    - When you want updates on every [set] call regardless of value
    
    {[
      let buffer, set_buffer = Signal.create_physical (Bytes.create 1024)
    ]}
*)
val create_physical : 'a -> 'a t * ('a -> unit)

(** Read the current value of a signal.
    If called inside an effect or memo, registers a dependency.
    
    {[
      let value = Signal.get count
    ]}
*)
val get : 'a t -> 'a

(** Read the current value without tracking dependency.
    Useful when you need the value but don't want to subscribe.
    
    {[
      let value = Signal.peek count  (* no subscription *)
    ]}
*)
val peek : 'a t -> 'a

(** Set a new value for the signal.
    Notifies all dependents if the value changed (according to equals).
    
    {[
      Signal.set count 42
    ]}
*)
val set : 'a t -> 'a -> unit

(** Update the signal based on its current value.
    
    {[
      Signal.update count (fun n -> n + 1)
    ]}
*)
val update : 'a t -> ('a -> 'a) -> unit

(** {2 Advanced API} *)

(** Subscribe to a signal manually. Returns an unsubscribe function.
    Prefer using [Effect.create] for automatic dependency tracking. *)
val subscribe : 'a t -> (unit -> unit) -> (unit -> unit)

module Unsafe : sig
  type 'a t = 'a Reactive.signal
  val create : ?equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  val create_eq : equals:('a -> 'a -> bool) -> 'a -> 'a t * ('a -> unit)
  val create_physical : 'a -> 'a t * ('a -> unit)
  val get : 'a t -> 'a
  val peek : 'a t -> 'a
  val set : 'a t -> 'a -> unit
  val update : 'a t -> ('a -> 'a) -> unit
  val subscribe : 'a t -> (unit -> unit) -> (unit -> unit)
end

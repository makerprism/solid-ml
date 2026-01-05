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
*)

(** A reactive value that tracks its dependents. *)
type 'a t

(** Create a new signal with an initial value.
    Returns a tuple of (signal, setter function).

    {[
      let count, set_count = Signal.create 0
    ]}
*)
val create : 'a -> 'a t * ('a -> unit)

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
    Notifies all dependents to re-run.

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

(** {2 Internal API}

    These functions are used by Effect and Memo modules.
    You typically don't need to call them directly.
*)

(** Subscribe to a signal. Returns an unsubscribe function. *)
val subscribe : 'a t -> (unit -> unit) -> (unit -> unit)

(** Get the current tracking context (if any). *)
val get_tracking_context : unit -> (unit -> unit) option

(** Set the tracking context for dependency collection. *)
val set_tracking_context : (unit -> unit) option -> unit

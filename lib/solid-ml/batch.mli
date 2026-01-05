(** Batch multiple signal updates.

    By default, each signal update immediately notifies subscribers.
    Use [batch] to group multiple updates and only notify once at the end.

    {[
      (* Without batch: two separate notifications *)
      Signal.set first_name "John";
      Signal.set last_name "Doe";

      (* With batch: single notification after both updates *)
      Batch.run (fun () ->
        Signal.set first_name "John";
        Signal.set last_name "Doe"
      )
    ]}
*)

(** Run a function with batched updates.
    Signal updates inside [fn] are collected and subscribers
    are notified only once after [fn] completes.
*)
val run : (unit -> 'a) -> 'a

(** Check if we're currently inside a batch. *)
val is_batching : unit -> bool

(** Queue a notification to run after batch completes.
    If not batching, runs immediately.
    Used internally by Signal module.
*)
val queue_notification : (unit -> unit) -> unit

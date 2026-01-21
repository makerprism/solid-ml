(** Batch multiple signal updates.
    
    In the new reactive system, updates are automatically batched
    within a single synchronous execution context. This module provides
    explicit batching for cases where you want to ensure updates are
    grouped together.
    
    {[
      (* Without batch: updates may trigger multiple effect runs *)
      Signal.set first_name "John";
      Signal.set last_name "Doe";
      
      (* With batch: single update cycle after both changes *)
      (* token comes from Runtime.run *)
      Batch.run token (fun () ->
        Signal.set first_name "John";
        Signal.set last_name "Doe"
      )
    ]}
*)

(** Run a function with batched updates.
    Signal updates inside [fn] are collected and subscribers
    are notified only once after [fn] completes.
    
    Batches can be nested - inner batches are merged with outer ones. *)
type token = Runtime.token

val run : token -> (unit -> 'a) -> 'a

(** Check if we're currently inside a batch/update cycle. *)
val is_batching : unit -> bool

module Unsafe : sig
  val run : (unit -> 'a) -> 'a
end

(** Memoized derived values with automatic dependency tracking.
    
    Memos are cached computations that only re-run when their
    dependencies change. Like SolidJS, memos are eager - they
    compute immediately on creation and re-run when dependencies change.
    
    {[
      let count, set_count = Signal.create 2
      
      (* Computes immediately, only recomputes when count changes *)
      let doubled = Memo.create (fun () -> Signal.get count * 2)
      
      Memo.get doubled  (* 4 *)
      set_count 5
      Memo.get doubled  (* 10 *)
    ]}
*)

(** A memoized computation that can be read like a signal *)
type 'a t = 'a Reactive.memo

(** Create a memoized computation.
    The function is called immediately on creation (eager, like SolidJS),
    and re-runs when dependencies change.
    
    @param equals Custom equality function (default: structural equality)
    
    {[
      let full_name = Memo.create (fun () ->
        Signal.get first_name ^ " " ^ Signal.get last_name
      )
    ]}
*)
val create : ?equals:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t

(** Create a memo with a custom equality function.
    The memo only updates its value (and notifies dependents) when
    the new value is not equal to the old value according to [eq].
    
    {[
      let items = Memo.create_with_equals
        ~eq:(fun a b -> List.length a = List.length b)
        (fun () -> compute_list ())
    ]}
*)
val create_with_equals : eq:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t

(** Read the memo's value, recomputing if stale.
    If called inside a computation, registers a dependency. *)
val get : 'a t -> 'a

(** Read the cached value without recomputing or tracking.
    Note: This may return a stale value. *)
val peek : 'a t -> 'a

module Unsafe : sig
  val create : ?equals:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t
  val create_with_equals : eq:('a -> 'a -> bool) -> (unit -> 'a) -> 'a t
  val get : 'a t -> 'a
  val peek : 'a t -> 'a
end

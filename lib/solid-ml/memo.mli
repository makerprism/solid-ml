(** Memoized derived values.

    Memos are cached computations that only re-run when their
    dependencies change. They act like signals but derive their
    value from other signals.

    {[
      let count, set_count = Signal.create 2
      
      (* Only recomputes when count changes *)
      let doubled = Memo.create (fun () -> Signal.get count * 2)
      
      Signal.get doubled  (* 4 *)
      set_count 5
      Signal.get doubled  (* 10 *)
    ]}
*)

(** Create a memoized computation.
    The function runs immediately and re-runs when dependencies change.
    Returns a signal that holds the computed value.

    {[
      let full_name = Memo.create (fun () ->
        Signal.get first_name ^ " " ^ Signal.get last_name
      )
    ]}
*)
val create : (unit -> 'a) -> 'a Signal.t

(** Create a memo with a custom equality function.
    The memo only updates its value (and notifies dependents) when
    the new value is not equal to the old value according to [eq].

    {[
      let items = Memo.create_with_equals
        ~eq:(fun a b -> List.length a = List.length b)
        (fun () -> compute_list ())
    ]}
*)
val create_with_equals : eq:('a -> 'a -> bool) -> (unit -> 'a) -> 'a Signal.t

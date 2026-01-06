(** Reactive effects that auto-track dependencies.
    
    Effects are side effects that automatically re-run when any
    signal they read changes.
    
    {[
      let count, set_count = Signal.create 0
      
      (* This effect re-runs whenever count changes *)
      Effect.create (fun () ->
        print_endline ("Count is: " ^ string_of_int (Signal.get count))
      )
      
      set_count 1  (* prints "Count is: 1" *)
      set_count 2  (* prints "Count is: 2" *)
    ]}
*)

(** Create an effect that re-runs when its dependencies change.
    The effect runs immediately once, then re-runs whenever any
    signal read during execution changes.
    
    {[
      Effect.create (fun () ->
        (* Any Signal.get calls here are tracked *)
        let value = Signal.get some_signal in
        do_something_with value
      )
    ]}
*)
val create : (unit -> unit) -> unit

(** Create an effect that returns a cleanup function.
    The cleanup runs before each re-execution and on disposal.
    
    {[
      Effect.create_with_cleanup (fun () ->
        let subscription = subscribe_to_something () in
        (* Return cleanup function *)
        fun () -> unsubscribe subscription
      )
    ]}
*)
val create_with_cleanup : (unit -> (unit -> unit)) -> unit

(** Run a function without tracking any signal reads.
    Useful when you want to read a signal without subscribing.
    
    {[
      Effect.create (fun () ->
        let tracked = Signal.get signal_a in
        let untracked = Effect.untrack (fun () -> Signal.get signal_b) in
        (* Effect only re-runs when signal_a changes, not signal_b *)
        ...
      )
    ]}
*)
val untrack : (unit -> 'a) -> 'a

(** Create an effect with explicit dependencies (like SolidJS's `on`).
    
    Unlike [create], which automatically tracks all signals read,
    [on] explicitly specifies which signals to track via the [deps] function.
    The body of [fn] is NOT tracked - only [deps] is tracked.
    
    {[
      let count, set_count = Signal.create 0 in
      let name, set_name = Signal.create "Alice" in
      
      (* Only re-runs when count changes, NOT when name changes *)
      Effect.on
        (fun () -> Signal.get count)
        (fun ~value ~prev ->
          (* Reading name here does NOT cause re-run when name changes *)
          let n = Signal.get name in
          print_endline (Printf.sprintf "%s: count %d -> %d" n prev value))
    ]}
    
    @param defer If true, skip the first execution (default: false)
    @param deps Function that reads signals to track
    @param fn Callback receiving ~value (current) and ~prev (previous dep value) *)
val on : ?defer:bool -> (unit -> 'a) -> (value:'a -> prev:'a -> unit) -> unit

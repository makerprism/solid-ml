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

(** Create a render effect that runs before user effects. *)
val create_render_effect : (unit -> unit) -> unit

(** Alias for [create_render_effect]. *)
val create_computed : (unit -> unit) -> unit

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

(** Create a render effect with a cleanup function. *)
val create_render_effect_with_cleanup : (unit -> (unit -> unit)) -> unit

(** Alias for [create_render_effect_with_cleanup]. *)
val create_computed_with_cleanup : (unit -> (unit -> unit)) -> unit

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

(** Create an effect that skips the side effect on first execution.
    Useful when initial values are set directly and only updates need the effect.
    
    The [~track] function is called on every execution to read signals and
    establish dependencies. The [~run] function is called only after the first
    execution to perform the side effect.
    
    This is more efficient than using a mutable ref to skip the first run,
    and cleaner than using [on ~defer:true] for simple cases.
    
    {[
      (* Set initial value directly *)
      Dom.set_text_content el (Signal.peek label);
      
      (* Effect only updates on changes, not initial render *)
      Effect.create_deferred
        ~track:(fun () -> Signal.get label)
        ~run:(fun label -> Dom.set_text_content el label)
    ]}
    
    @param track Function that reads signals to track (auto-tracked)
    @param run Side effect function, receives the tracked value *)
val create_deferred : track:(unit -> 'a) -> run:('a -> unit) -> unit

(** Create a reaction that tracks dependencies explicitly.
    Returns a function that establishes dependencies when called. *)
val create_reaction : (value:'a -> prev:'a -> unit) -> (unit -> 'a) -> unit

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
    @param initial Optional initial value for ~prev when defer is true
    @param deps Function that reads signals to track
    @param fn Callback receiving ~value (current) and ~prev (previous dep value) *)
val on :
  ?defer:bool -> ?initial:'a -> (unit -> 'a) -> (value:'a -> prev:'a -> unit) -> unit

module Unsafe : sig
  val create : (unit -> unit) -> unit
  val create_render_effect : (unit -> unit) -> unit
  val create_computed : (unit -> unit) -> unit
  val create_with_cleanup : (unit -> (unit -> unit)) -> unit
  val create_render_effect_with_cleanup : (unit -> (unit -> unit)) -> unit
  val create_computed_with_cleanup : (unit -> (unit -> unit)) -> unit
  val untrack : (unit -> 'a) -> 'a
  val create_deferred : track:(unit -> 'a) -> run:('a -> unit) -> unit
  val create_reaction : (value:'a -> prev:'a -> unit) -> (unit -> 'a) -> unit
  val on :
    ?defer:bool -> ?initial:'a -> (unit -> 'a) -> (value:'a -> prev:'a -> unit) -> unit
end

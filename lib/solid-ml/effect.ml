(** Reactive effects with automatic dependency tracking.
    
    Effects are computations that re-run when their dependencies change.
    They are used for side effects like DOM updates, logging, etc.
*)

module Internal = Solid_ml_internal
module R = Reactive.R

(** Create an effect that runs when dependencies change.
    
    The effect function is called immediately, and then re-called
    whenever any signal read during execution changes. *)
let create = R.create_effect

(** Create an effect with a cleanup function.
    
    The effect function should return a cleanup function that will
    be called before the next execution and when the effect is disposed. *)
let create_with_cleanup = R.create_effect_with_cleanup

(** Execute a function without tracking dependencies. *)
let untrack = R.untrack

(** Create an effect that skips the side effect on first execution.
    Useful when initial values are set directly and only updates need the effect.
    
    The ~track function is called on every execution to read signals and
    establish dependencies. The ~run function is called only after the first
    execution to perform the side effect. *)
let create_deferred = R.create_effect_deferred

(** Create an effect with explicit dependencies (like SolidJS's `on`).
    
    Unlike [create], which automatically tracks all signals read during execution,
    [on] explicitly specifies which signals to track via the [deps] function.
    The [fn] function receives the current and previous values of deps.
    
    The body of [fn] is NOT tracked - only [deps] is tracked.
    
    {[
      let count, set_count = Signal.create 0 in
      let name, set_name = Signal.create "Alice" in
      
      (* Only tracks count, not name *)
      Effect.on
        (fun () -> Signal.get count)
        (fun ~value ~prev ->
          (* Reading name here does NOT cause re-run *)
          print_endline (Printf.sprintf "count: %d -> %d" prev value))
    ]}
    
    @param deps Function that reads signals to track (auto-tracked)
    @param fn Function called with ~value (current) and ~prev (previous)
    @param defer If true, skip running on first execution (default: false)
    @param initial Optional initial value for ~prev when defer is true *)
let on (type a) ?(defer = false) ?initial (deps : unit -> a) (fn : value:a -> prev:a -> unit) : unit =
  let prev = ref None in
  let first_run = ref true in
  R.create_effect (fun () ->
    let value = deps () in
    R.untrack (fun () ->
      if !first_run then begin
        first_run := false;
        let initial_prev = match initial with
          | Some v -> v
          | None -> value
        in
        prev := Some initial_prev;
        if not defer then begin
          fn ~value ~prev:initial_prev;
          prev := Some value
        end
      end else begin
        let prev_val = match !prev with
          | Some p -> p
          | None -> value
        in
        fn ~value ~prev:prev_val;
        prev := Some value
      end
    )
  )

module Unsafe = struct
  let create = R.create_effect
  let create_with_cleanup = R.create_effect_with_cleanup
  let untrack = R.untrack
  let create_deferred = R.create_effect_deferred

  let on (type a) ?(defer = false) ?initial (deps : unit -> a) (fn : value:a -> prev:a -> unit) : unit =
    let prev = ref None in
    let first_run = ref true in
    R.create_effect (fun () ->
      let value = deps () in
      R.untrack (fun () ->
        if !first_run then begin
          first_run := false;
          let initial_prev = match initial with
            | Some v -> v
            | None -> value
          in
          prev := Some initial_prev;
          if not defer then begin
            fn ~value ~prev:initial_prev;
            prev := Some value
          end
        end else begin
          let prev_val = match !prev with
            | Some p -> p
            | None -> value
          in
          fn ~value ~prev:prev_val;
          prev := Some value
        end
      )
    )
end

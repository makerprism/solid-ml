(** Reactive effects with automatic dependency tracking.
    
    Effects are computations that re-run when their dependencies change.
    They are used for side effects like DOM updates, logging, etc.
    
    This implementation matches SolidJS's effect architecture with
    proper cleanup and the STALE/PENDING state machine.
*)

(** Create an effect that runs when dependencies change.
    
    The effect function is called immediately, and then re-called
    whenever any signal read during execution changes.
    
    Effects are automatically disposed when their owner is disposed. *)
let create fn =
  let comp = Reactive.create_computation
    ~fn:(fun _ -> fn (); Obj.repr ())
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Reactive.Stale
  in
  comp.user <- true;
  
  (* Run immediately or queue *)
  let rt = Reactive.get_runtime () in
  if rt.in_update then
    rt.effects <- comp :: rt.effects
  else
    Reactive.run_updates (fun () ->
      Reactive.run_top comp
    ) true

(** Create an effect with a cleanup function.
    
    The effect function should return a cleanup function that will
    be called before the next execution and when the effect is disposed.
    
    Example:
    {[
      Effect.create_with_cleanup (fun () ->
        let subscription = subscribe_to_something () in
        fun () -> unsubscribe subscription
      )
    ]} *)
let create_with_cleanup fn =
  let cleanup_ref = ref (fun () -> ()) in
  
  let comp = Reactive.create_computation
    ~fn:(fun _ ->
      (* Run previous cleanup *)
      !cleanup_ref ();
      (* Run effect and store new cleanup *)
      let new_cleanup = fn () in
      cleanup_ref := new_cleanup;
      Obj.repr ()
    )
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Reactive.Stale
  in
  comp.user <- true;
  
  (* Register final cleanup *)
  Reactive.on_cleanup (fun () -> !cleanup_ref ());
  
  (* Run immediately or queue *)
  let rt = Reactive.get_runtime () in
  if rt.in_update then
    rt.effects <- comp :: rt.effects
  else
    Reactive.run_updates (fun () ->
      Reactive.run_top comp
    ) true

(** Execute a function without tracking dependencies.
    
    Any signals read inside [fn] will not be registered as
    dependencies of the current computation.
    
    Example:
    {[
      Effect.create (fun () ->
        let tracked = Signal.get some_signal in
        let untracked = Effect.untrack (fun () -> Signal.get other_signal) in
        (* Effect only re-runs when some_signal changes *)
      )
    ]} *)
let untrack = Reactive.untrack

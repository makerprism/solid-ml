(** Reactive effects with automatic dependency tracking.
    
    Effects are computations that re-run when their dependencies change.
    They are used for side effects like DOM updates, logging, etc.
*)

module Internal = Solid_ml_internal

(** Create an effect that runs when dependencies change.
    
    The effect function is called immediately, and then re-called
    whenever any signal read during execution changes. *)
let create fn =
  let comp = Reactive.create_computation
    ~fn:(fun _ -> fn (); Obj.repr ())
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Internal.Types.Stale
  in
  comp.Internal.Types.user <- true;
  
  let rt = Reactive.get_runtime () in
  if rt.Internal.Types.in_update then
    rt.Internal.Types.effects <- comp :: rt.effects
  else
    Reactive.run_updates (fun () ->
      Reactive.run_top comp
    ) true

(** Create an effect with a cleanup function.
    
    The effect function should return a cleanup function that will
    be called before the next execution and when the effect is disposed. *)
let create_with_cleanup fn =
  let cleanup_ref = ref (fun () -> ()) in
  
  let comp = Reactive.create_computation
    ~fn:(fun _ ->
      !cleanup_ref ();
      let new_cleanup = fn () in
      cleanup_ref := new_cleanup;
      Obj.repr ()
    )
    ~init:(Obj.repr ())
    ~pure:false
    ~initial_state:Internal.Types.Stale
  in
  comp.Internal.Types.user <- true;
  
  Reactive.on_cleanup (fun () -> !cleanup_ref ());
  
  let rt = Reactive.get_runtime () in
  if rt.Internal.Types.in_update then
    rt.Internal.Types.effects <- comp :: rt.effects
  else
    Reactive.run_updates (fun () ->
      Reactive.run_top comp
    ) true

(** Execute a function without tracking dependencies. *)
let untrack = Reactive.untrack

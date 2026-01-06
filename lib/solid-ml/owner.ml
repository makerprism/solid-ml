(** Ownership and disposal tracking.
    
    Owners form a tree structure that tracks the lifecycle of
    reactive computations. When an owner is disposed, all its
    child computations are cleaned up automatically.
    
    This module provides the public API for working with owners
    while the implementation lives in Reactive.
*)

(** Owner type (opaque to users) *)
type t = Reactive.owner

(** Get the current owner, if any *)
let get_owner () =
  match Reactive.get_runtime_opt () with
  | Some rt -> rt.owner
  | None -> None

(** Register a cleanup function with the current owner.
    
    The cleanup will be called when the owner is disposed or
    when the enclosing computation is re-run.
    
    If there is no current owner, the cleanup is ignored
    (it will never be called). *)
let on_cleanup = Reactive.on_cleanup

(** Create a root owner and run a function within it.
    
    The function receives a dispose callback that can be used
    to clean up the root and all its descendants.
    
    Example:
    {[
      let dispose = Owner.create_root (fun () ->
        let signal, set = Signal.create 0 in
        Effect.create (fun () ->
          print_int (Signal.get signal)
        );
        set 1
      ) in
      (* Later... *)
      dispose ()  (* Cleans up the effect *)
    ]}
    
    Note: create_root passes the dispose function to fn. *)
let create_root fn =
  match Reactive.get_runtime_opt () with
  | Some _ ->
    Reactive.create_root (fun dispose -> fn (); dispose)
  | None ->
    (* Create a temporary runtime for this root *)
    Reactive.run (fun () ->
      Reactive.create_root (fun dispose -> fn (); dispose)
    )

(** Run a function with a new owner scope.
    
    Returns a tuple of (result, dispose_fn).
    The dispose_fn can be called to clean up the owner and
    all computations created within the function.
    
    Example:
    {[
      let (result, dispose) = Owner.run_with_owner (fun () ->
        (* computations created here belong to new owner *)
        42
      ) in
      (* result = 42 *)
      dispose ()  (* clean up *)
    ]} *)
let run_with_owner fn =
  Reactive.create_root (fun dispose ->
    let result = fn () in
    (result, dispose)
  )

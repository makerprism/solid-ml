(** Ownership and disposal tracking.
    
    The ownership system tracks which reactive computations (effects, memos)
    are "owned" by which parent computation. When a parent is disposed,
    all its children are automatically cleaned up.
    
    This enables:
    - Automatic cleanup of effects when components unmount
    - Nested effect scopes
    - Resource management without manual cleanup
    
    {[
      (* Create a root that owns everything inside *)
      let dispose = Owner.create_root (fun () ->
        let count, _set_count = Signal.create 0 in
        
        Effect.create (fun () ->
          print_endline (string_of_int (Signal.get count))
        );
        
        (* Effect is owned by the root *)
      ) in
      
      (* Later: dispose everything *)
      dispose ()
    ]}
*)

(** An ownership scope that tracks child computations (opaque) *)
type t = Reactive.owner

(** Create a new root ownership scope.
    Returns a dispose function that cleans up all owned computations.

    The callback does not receive the dispose function; it is returned to the caller.
    
    If called outside a runtime, creates a temporary one.
    
    {[
      let dispose = Owner.create_root (fun () ->
        (* Effects created here are owned by this root *)
        Effect.create (fun () -> ...)
      ) in
      dispose ()  (* Cleans up everything *)
    ]}
*)
val create_root : (unit -> unit) -> (unit -> unit)

(** Run a function within a new ownership scope.
    The scope is a child of the current owner (if any).
    Returns the result and a dispose function.
*)
val run_with_owner : (unit -> 'a) -> 'a * (unit -> unit)

(** Get the current owner (if any).
    Returns None if not inside any ownership scope.
*)
val get_owner : unit -> t option

(** Register a cleanup function with the current owner.
    The cleanup will run when the owner is disposed.
    If there's no current owner, the cleanup is ignored.
    
    {[
      Owner.on_cleanup (fun () ->
        print_endline "Cleaning up!"
      )
    ]}
*)
val on_cleanup : (unit -> unit) -> unit

(** Create an error boundary (like SolidJS's catchError).
    
    Wraps a computation and catches any exceptions thrown during execution.
    The error handler receives the exception and can return a fallback value.
    
    {[
      let result = Owner.catch_error
        (fun () ->
          if bad_input then failwith "Invalid input";
          compute_something ())
        (fun exn ->
          log_error exn;
          default_value)
    ]}
    
    @param fn Function that might throw an exception
    @param handler Error handler that returns a fallback value
    @return Result of [fn], or handler's fallback if [fn] threw *)
val catch_error : (unit -> 'a) -> (exn -> 'a) -> 'a

module Unsafe : sig
  val create_root : (unit -> unit) -> (unit -> unit)
  val run_with_owner : (unit -> 'a) -> 'a * (unit -> unit)
  val on_cleanup : (unit -> unit) -> unit
  val get_owner : unit -> t option
end

(** Ownership and disposal tracking.
    
    Owners form a tree structure that tracks the lifecycle of
    reactive computations. When an owner is disposed, all its
    child computations are cleaned up automatically.
*)

module Internal = Solid_ml_internal

(** Owner type (opaque to users) *)
type t = Reactive.owner

(** Get the current owner, if any *)
let get_owner () =
  match Reactive.get_runtime_opt () with
  | Some rt -> rt.Internal.Types.owner
  | None -> None

(** Register a cleanup function with the current owner. *)
let on_cleanup = Reactive.on_cleanup

(** Create a root owner and run a function within it.

    Returns a dispose callback that can be used to clean up the root
    and all its descendants. The callback is returned to the caller. *)
let create_root fn =
  Reactive.create_root (fun dispose -> fn (); dispose)

(** Run a function with a new owner scope.
    
    Returns a tuple of (result, dispose_fn). *)
let run_with_owner fn =
  Reactive.create_root (fun dispose ->
    let result = fn () in
    (result, dispose)
  )

(** Create an error boundary (like SolidJS's catchError).
    
    Wraps a computation and catches any exceptions thrown during execution.
    The error handler receives the exception and can return a fallback value.
    
    Unlike SolidJS which uses a setter to reset, this returns the result
    directly since OCaml exceptions are synchronous.
    
    {[
      let result = Owner.catch_error
        (fun () ->
          (* Code that might throw *)
          if some_condition then failwith "error";
          "success")
        (fun exn ->
          Printf.printf "Caught: %s\n" (Printexc.to_string exn);
          "fallback")
    ]}
*)
let catch_error (fn : unit -> 'a) (handler : exn -> 'a) : 'a =
  try fn ()
  with exn -> handler exn

module Unsafe = struct
  let create_root fn =
    match Reactive.get_runtime_opt () with
    | Some _ ->
      Reactive.create_root (fun dispose -> fn (); dispose)
    | None ->
      Reactive.run (fun () ->
        Reactive.create_root (fun dispose -> fn (); dispose)
      )

  let run_with_owner fn =
    Reactive.create_root (fun dispose ->
      let result = fn () in
      (result, dispose)
    )

  let on_cleanup = Reactive.on_cleanup
  let get_owner = Reactive.get_owner
end

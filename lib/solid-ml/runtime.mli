(** Execution runtime that holds all reactive state.
    
    Each render/request should create its own runtime to ensure
    thread safety. All reactive operations happen within a runtime context.
    
    Uses Domain-local storage (OCaml 5) so each domain has independent
    runtime state. Safe for parallel execution with Domain.spawn.
    
    {[
      (* In a Dream handler *)
      let handler _req =
      let html = Render.to_string my_component in
        Dream.html html

      (* Or with explicit domain parallelism *)
      let results = Array.init 4 (fun i ->
        Domain.spawn (fun () ->
          Runtime.run (fun _token ->
            (* Each domain has independent reactive state *)
            ...
          )
        )
      ) |> Array.map Domain.join
    ]}
    
    {b Important}: Signals should not be shared across runtimes or domains.
    Each runtime maintains its own reactive graph. Sharing signals between
    runtimes leads to undefined behavior (subscribers from one runtime
    may be notified in another runtime's context).
*)

(** The runtime state for a reactive execution context (opaque) *)
type t = Reactive.runtime

(** Token required for strict APIs *)
type token

(** An owner node in the reactive tree (opaque) *)
type owner = Reactive.owner

(** Get the current runtime. Raises if none active. *)
val get_current : unit -> t

(** Get the current runtime if any *)
val get_current_opt : unit -> t option

(** Create a fresh runtime and run function within it.
    This is the primary entry point for reactive code.
    
    {[
      Runtime.run (fun token ->
        let count = Signal.create token 0 in
        Effect.create token (fun () ->
          print_int (Signal.get count)
        );
        Signal.set count 1
      )
    ]} *)
val run : (token -> 'a) -> 'a

module Unsafe : sig
  val run : (unit -> 'a) -> 'a
end

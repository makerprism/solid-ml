(** Execution runtime that holds all reactive state.

    Each render/request should create its own runtime to ensure
    thread safety. All reactive operations happen within a runtime context.

    {[
      (* In a Dream handler *)
      let handler _req =
        let html = Runtime.run (fun () ->
          Render.to_string my_component
        ) in
        Dream.html html
    ]}
*)

(** An owner node in the reactive tree *)
type owner = {
  mutable cleanups : (unit -> unit) list;
  mutable children : owner list;
  mutable disposed : bool;
  parent : owner option;
  mutable contexts : (int * Obj.t) list;
}

(** The runtime state for a reactive execution context *)
type t = {
  mutable current_owner : owner option;
  mutable tracking_context : (unit -> unit) option;
  mutable pending_unsubscribes : (unit -> unit) list;
  mutable batching : bool;
  mutable pending_notifications : (unit -> unit) list;
}

(** Create a new empty runtime *)
val create : unit -> t

(** Get the current runtime. Raises if none active. *)
val get_current : unit -> t

(** Get the current runtime if any *)
val get_current_opt : unit -> t option

(** Run a function with the given runtime as current *)
val run_with : t -> (unit -> 'a) -> 'a

(** Create a fresh runtime and run function within it *)
val run : (unit -> 'a) -> 'a

(** Backend module type for platform-specific runtime storage.
    
    The only platform-specific part of the reactive system is how
    the current runtime is stored and accessed:
    
    - Server: Domain-local storage (thread-safe isolation per domain)
    - Browser: Global ref (safe in single-threaded JS)
    
    All other state (runtime fields, computation state, etc.) uses
    regular OCaml mutable fields since access is single-threaded
    within a runtime context.
*)

open Types

(** Module type for runtime storage backends *)
module type S = sig
  (** Get the current runtime, if any *)
  val get_runtime : unit -> runtime option
  
  (** Set the current runtime *)
  val set_runtime : runtime option -> unit
  
  (** Handle an error from a computation.
      @param exn The exception that was raised
      @param context Description like "effect" or "memo" 
      
      Server implementation re-raises, browser logs to console. *)
  val handle_error : exn -> string -> unit

  (** Schedule a transition flush. Browser should defer (setTimeout),
      server can run immediately. *)
  val schedule_transition : (unit -> unit) -> unit
end

(** Global ref backend - works on both server and browser.
    
    On server, prefer the DLS backend from solid-ml for thread safety.
    On browser, this is the correct choice (JS is single-threaded). *)
module Global : S = struct
  let current_runtime : runtime option ref = ref None
  
  let get_runtime () = !current_runtime
  let set_runtime rt = current_runtime := rt
  
  (* Default error handling - re-raise. 
     Browser package can shadow this with console.error *)
  let handle_error exn _context = raise exn

  let schedule_transition fn = fn ()
end

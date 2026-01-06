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
end

(** Global ref backend - for browser (single-threaded) *)
module Global : S = struct
  let current_runtime : runtime option ref = ref None
  
  let get_runtime () = !current_runtime
  let set_runtime rt = current_runtime := rt
  
  let handle_error exn _context = raise exn
end

(** DLS backend - for server (thread-safe per domain) *)
module DLS : S = struct
  let runtime_key : runtime option Domain.DLS.key =
    Domain.DLS.new_key (fun () -> None)
  
  let get_runtime () = Domain.DLS.get runtime_key
  let set_runtime rt = Domain.DLS.set runtime_key rt
  
  let handle_error exn _context = raise exn
end

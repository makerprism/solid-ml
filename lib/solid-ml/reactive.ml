(** Server-side reactive system.
    
    Uses Domain-local storage (DLS) for thread-safe isolation.
    Each domain gets its own independent reactive runtime, making
    this safe for concurrent server requests.
    
    This module instantiates the shared functor with the DLS backend
    and re-exports all the reactive primitives.
*)

(** {1 Internal Module (for advanced use only)} *)

module Internal = Solid_ml_internal

(** {1 DLS Backend (Server-specific)} *)

module Backend_DLS : Internal.Backend.S = struct
  let runtime_key : Internal.Types.runtime option Domain.DLS.key =
    Domain.DLS.new_key (fun () -> None)
  
  let get_runtime () = Domain.DLS.get runtime_key
  let set_runtime rt = Domain.DLS.set runtime_key rt
  
  (* Server should not swallow errors *)
  let handle_error exn _context = raise exn

  let schedule_transition fn = fn ()
end

(** {1 Instantiate with DLS Backend} *)

module R = Internal.Reactive_functor.Make(Backend_DLS)

(** {1 Re-export Types} *)

type computation_state = Internal.Types.computation_state =
  | Clean
  | Stale  
  | Pending

type source_kind = Internal.Types.source_kind =
  | Signal_source
  | Memo_source

type signal_state = Internal.Types.signal_state
type owner = Internal.Types.owner
type computation = Internal.Types.computation
type runtime = Internal.Types.runtime

(** Typed signal - the type parameter provides compile-time safety *)
type 'a signal = 'a Internal.Types.signal

(** Typed memo *)
type 'a memo = 'a Internal.Types.memo

(** {1 Runtime API} *)

let get_runtime = R.get_runtime
let get_runtime_opt = R.get_runtime_opt
let create_runtime = Internal.Types.create_runtime
let run = R.run

(** {1 Owner API} *)

let create_root = R.create_root
let on_cleanup = R.on_cleanup
let get_owner = R.get_owner

(** {1 Tracking API} *)

let untrack = R.untrack

(** {1 Typed Signal API} *)

let create_signal = R.create_typed_signal
let read_signal = R.read_typed_signal
let write_signal = R.write_typed_signal
let peek_signal = R.peek_typed_signal

(** {1 Typed Memo API} *)

let create_memo = R.create_typed_memo
let read_memo = R.read_typed_memo
let peek_memo = R.peek_typed_memo

(** {1 Computation API (for Effect/Memo implementations)} *)

let create_computation = R.create_computation
let clean_node = R.clean_node
let run_computation = R.run_computation
let run_top = R.run_top
let run_updates = R.run_updates
let run_transition = R.run_transition
let transition_pending_signal = R.transition_pending_signal
let look_upstream = R.look_upstream

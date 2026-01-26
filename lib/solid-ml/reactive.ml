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

(** {1 Strict API} *)

module Strict : sig
  type token

  val run : (token -> 'a) -> 'a
  val create_root : (token -> 'a) -> 'a * (unit -> unit)

  val create_signal : token -> ?equals:('a -> 'a -> bool) -> 'a -> 'a signal
  val read_signal : token -> 'a signal -> 'a
  val write_signal : token -> 'a signal -> 'a -> unit
  val update_signal : token -> 'a signal -> ('a -> 'a) -> unit
  val peek_signal : token -> 'a signal -> 'a

  val create_memo : token -> ?equals:('a -> 'a -> bool) -> (unit -> 'a) -> 'a memo
  val read_memo : token -> 'a memo -> 'a
  val peek_memo : token -> 'a memo -> 'a

  val create_effect : token -> (unit -> unit) -> unit
  val create_effect_with_cleanup : token -> (unit -> (unit -> unit)) -> unit
  val untrack : token -> (unit -> 'a) -> 'a
end = struct
  type token = unit

  let run f =
    R.run (fun () ->
      let token = () in
      f token)

  let create_root f =
    R.create_root (fun dispose ->
      let token = () in
      let result = f token in
      (result, dispose))

  let create_signal _ = R.create_typed_signal
  let read_signal _ = R.read_typed_signal
  let write_signal _ = R.write_typed_signal
  let update_signal _ s f = R.write_typed_signal s (f (R.peek_typed_signal s))
  let peek_signal _ = R.peek_typed_signal

  let create_memo _ = R.create_typed_memo
  let read_memo _ = R.read_typed_memo
  let peek_memo _ = R.peek_typed_memo

  let create_effect _ = R.create_effect
  let create_effect_with_cleanup _ = R.create_effect_with_cleanup
  let untrack _ = R.untrack
end

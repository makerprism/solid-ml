(** Browser-side reactive core using the shared functor.
    
    Uses global refs for runtime storage (safe in single-threaded JS).
    Errors are logged to console instead of re-raised to prevent
    breaking the entire application.
*)

module Internal = Solid_ml_internal

(** {1 Browser Backend with console.error} *)

external console_error : string -> unit = "error" [@@mel.scope "console"]

(** Lightweight exception to string - avoids heavy Printexc/Printf deps *)
let exn_to_string : exn -> string = [%mel.raw {|
  function(exn) {
    if (exn && exn.MEL_EXN_ID) {
      var msg = exn.MEL_EXN_ID;
      if (exn._1 !== undefined) msg += ": " + String(exn._1);
      return msg;
    } else if (exn instanceof Error) {
      return exn.message || exn.toString();
    } else {
      return String(exn);
    }
  }
|}]

module Backend_Browser : Internal.Backend.S = struct
  let current_runtime : Internal.Types.runtime option ref = ref None
  
  let get_runtime () = !current_runtime
  let set_runtime rt = current_runtime := rt
  
  (* Browser logs errors to console instead of crashing.
     Note: We use our local exn_to_string to avoid circular dependency with Dom. *)
  let handle_error exn context =
    console_error ("solid-ml: Error in " ^ context ^ ": " ^ exn_to_string exn)
end

(** {1 Instantiate with Browser Backend} *)

module R = Internal.Reactive_functor.Make(Backend_Browser)

(** {1 Types} *)

type computation_state = Internal.Types.computation_state = Clean | Stale | Pending
type 'a signal = 'a Internal.Types.signal
type 'a memo = 'a Internal.Types.memo
type owner = Internal.Types.owner
type computation = Internal.Types.computation
type 'a context = 'a R.context


(** {1 Signal API} *)

let create_signal = R.create_typed_signal
let get_signal (type a) (signal : a signal) : a =
  R.read_typed_signal signal
let set_signal (type a) (signal : a signal) (value : a) : unit =
  R.write_typed_signal signal value
let peek_signal = R.peek_typed_signal
let update_signal s f = set_signal s (f (peek_signal s))

(** {1 Effect API} *)

let create_effect = R.create_effect
let create_effect_with_cleanup = R.create_effect_with_cleanup
let create_effect_deferred = R.create_effect_deferred
let untrack = R.untrack

(** {1 Memo API} *)

let create_memo = R.create_typed_memo
let get_memo = R.read_typed_memo
let peek_memo = R.peek_typed_memo

(** {1 Owner API} *)

let on_cleanup = R.on_cleanup
let get_owner = R.get_owner

let with_owner (owner : owner option) (fn : unit -> 'a) : 'a =
  match R.get_runtime_opt () with
  | None -> fn ()
  | Some rt ->
    let prev_owner = rt.Internal.Types.owner in
    rt.owner <- owner;
    match fn () with
    | value ->
      rt.owner <- prev_owner;
      value
    | exception exn ->
      rt.owner <- prev_owner;
      raise exn

let create_root f =
  (* Ensure we have a runtime.
     
     Unlike the server, the browser runtime should persist globally
     so that event handlers (which run outside create_root) can still
     access signals. We use ensure_runtime to create a runtime that
     stays active after this function returns. *)
  match R.get_runtime_opt () with
  | Some _ -> R.create_root (fun dispose -> (f (), dispose))
  | None ->
    (* Create a persistent runtime for the browser *)
    let rt = Internal.Types.create_runtime () in
    Backend_Browser.set_runtime (Some rt);
    R.create_root (fun dispose -> (f (), dispose))

let run_with_owner = create_root

(** {1 Batch API} *)

let batch fn = R.run_updates fn false

let run_updates fn = R.run_updates fn false
let run_transition fn = R.run_transition fn
let transition_pending_signal () = R.transition_pending_signal ()

let run_updates_nested fn =
  match R.get_runtime_opt () with
  | None -> R.run_updates fn false
  | Some rt ->
    if rt.Internal.Types.in_update then (
      rt.in_update <- false;
      let res = R.run_updates fn false in
      rt.in_update <- true;
      res)
    else
      R.run_updates fn false

(** {1 Context API} *)

let create_context = R.create_context
let use_context = R.use_context
let provide_context = R.provide_context

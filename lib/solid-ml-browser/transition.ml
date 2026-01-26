open Reactive_core

type pending = bool signal

let pending_signal () : pending =
  transition_pending_signal ()

let pending () : bool =
  get_signal (pending_signal ())

let run fn =
  run_transition fn

open Reactive

type pending = bool signal

let pending_signal () : pending =
  transition_pending_signal ()

let pending () : bool =
  read_signal (pending_signal ())

let run fn =
  run_transition fn

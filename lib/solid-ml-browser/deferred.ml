open Reactive_core

type 'a t = 'a signal

let create ?equals ?timeout (source : 'a signal) : 'a t =
  let _ = timeout in
  let value = get_signal source in
  let deferred = create_signal ?equals value in
  Reactive.Effect.create (fun () ->
      let next = get_signal source in
      Transition.run (fun () -> set_signal deferred next));
  deferred

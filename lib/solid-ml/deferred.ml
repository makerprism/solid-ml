type 'a t = 'a Signal.t

let create ?equals ?timeout (source : 'a Signal.t) : 'a t =
  let _ = timeout in
  let value = Signal.Unsafe.get source in
  let deferred, set_deferred = Signal.Unsafe.create ?equals value in
  Effect.Unsafe.create (fun () ->
      let next = Signal.Unsafe.get source in
      Transition.run (fun () -> set_deferred next));
  deferred

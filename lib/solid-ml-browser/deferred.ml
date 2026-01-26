open Reactive_core

type 'a t = 'a signal

let create ?equals ?timeout (source : 'a signal) : 'a t =
  let value = get_signal source in
  let deferred = create_signal ?equals value in
  let pending = ref None in
  let schedule set_value =
    let ms = match timeout with Some ms -> ms | None -> 0 in
    let id = Dom.set_timeout (fun () ->
      pending := None;
      set_value ()) ms
    in
    pending := Some id
  in
  let cancel_pending () =
    match !pending with
    | None -> ()
    | Some id ->
      Dom.clear_timeout id;
      pending := None
  in
  Reactive.Effect.create (fun () ->
      let next = get_signal source in
      cancel_pending ();
      schedule (fun () -> Transition.run (fun () -> set_signal deferred next)));
  on_cleanup cancel_pending;
  deferred

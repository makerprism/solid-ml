(** Memoized derived values. *)

let create fn =
  (* Use structural equality by default for memos *)
  let signal, set_signal = Signal.create ~equals:(=) (fn ()) in
  
  (* Create effect that updates the signal when dependencies change *)
  Effect.create (fun () ->
    let new_value = fn () in
    set_signal new_value
  );
  
  signal

let create_with_equals ~eq fn =
  let signal, set_signal = Signal.create ~equals:eq (fn ()) in
  
  Effect.create (fun () ->
    let new_value = fn () in
    set_signal new_value
  );
  
  signal

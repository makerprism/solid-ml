(** Memoized derived values. *)

let create fn =
  (* Compute initial value *)
  let initial = fn () in
  let signal, set_signal = Signal.create initial in
  
  (* Create a re-run function that updates the signal when dependencies change *)
  let rec run () =
    Signal.set_tracking_context (Some run);
    let new_value = fn () in
    Signal.set_tracking_context None;
    (* Only update if value changed (using structural equality) *)
    if new_value <> Signal.peek signal then
      set_signal new_value
  in
  
  (* Set up initial tracking by running once *)
  Signal.set_tracking_context (Some run);
  let _ = fn () in
  Signal.set_tracking_context None;
  
  signal

let create_with_equals ~eq fn =
  let initial = fn () in
  let signal, set_signal = Signal.create initial in
  
  let rec run () =
    Signal.set_tracking_context (Some run);
    let new_value = fn () in
    Signal.set_tracking_context None;
    if not (eq new_value (Signal.peek signal)) then
      set_signal new_value
  in
  
  Signal.set_tracking_context (Some run);
  let _ = fn () in
  Signal.set_tracking_context None;
  
  signal

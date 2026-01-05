(** Reactive signals with automatic dependency tracking. *)

(** A signal holds a value and a set of subscribers *)
type 'a t = {
  mutable value : 'a;
  mutable subscribers : (unit -> unit) list;
  equals : ('a -> 'a -> bool) option;
}

let create ?equals initial =
  let signal = { value = initial; subscribers = []; equals } in
  let setter new_value =
    (* Check equality if provided *)
    let should_update = match signal.equals with
      | Some eq -> not (eq signal.value new_value)
      | None -> signal.value != new_value  (* Physical equality by default *)
    in
    if should_update then begin
      signal.value <- new_value;
      (* Notify all subscribers *)
      if Batch.is_batching () then
        List.iter (fun notify -> Batch.queue_notification notify) signal.subscribers
      else
        List.iter (fun notify -> notify ()) signal.subscribers
    end
  in
  (signal, setter)

let create_eq ~equals initial = create ~equals initial

let peek signal = signal.value

let get signal =
  (* If there's a tracking context, register as subscriber *)
  (match Runtime.get_current_opt () with
   | Some rt ->
     (match rt.tracking_context with
      | Some notify ->
        if not (List.memq notify signal.subscribers) then begin
          signal.subscribers <- notify :: signal.subscribers;
          (* Register unsubscribe with the effect *)
          let unsub = fun () ->
            signal.subscribers <- List.filter (fun s -> s != notify) signal.subscribers
          in
          rt.pending_unsubscribes <- unsub :: rt.pending_unsubscribes
        end
      | None -> ())
   | None -> ());
  signal.value

let set signal new_value =
  (* Check equality if provided *)
  let should_update = match signal.equals with
    | Some eq -> not (eq signal.value new_value)
    | None -> signal.value != new_value
  in
  if should_update then begin
    signal.value <- new_value;
    if Batch.is_batching () then
      List.iter (fun notify -> Batch.queue_notification notify) signal.subscribers
    else
      List.iter (fun notify -> notify ()) signal.subscribers
  end

let update signal f =
  set signal (f signal.value)

let subscribe signal notify =
  signal.subscribers <- notify :: signal.subscribers;
  (* Return unsubscribe function *)
  fun () ->
    signal.subscribers <- List.filter (fun s -> s != notify) signal.subscribers

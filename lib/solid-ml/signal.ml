(** Reactive signals with automatic dependency tracking.

    {b Important}: Signals should not be shared across runtimes or domains.
    Each signal belongs to the runtime in which it was created. Sharing
    signals between runtimes leads to undefined behavior.
*)

(** A signal holds a value and a set of subscribers *)
type 'a t = {
  mutable value : 'a;
  mutable subscribers : (unit -> unit) list;
  equals : 'a -> 'a -> bool;
}

let create ?(equals = (=)) initial =
  let signal = { value = initial; subscribers = []; equals } in
  let setter new_value =
    if not (signal.equals signal.value new_value) then begin
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

(** Create a signal using physical equality (==) for comparisons.
    Use this for signals holding mutable values or when you want
    updates on every set regardless of value. *)
let create_physical initial = create ~equals:(==) initial

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
  if not (signal.equals signal.value new_value) then begin
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

(** Reactive signals with automatic dependency tracking. *)

(** Current tracking context - set by Effect.create during execution *)
let tracking_context : (unit -> unit) option ref = ref None

let get_tracking_context () = !tracking_context
let set_tracking_context ctx = tracking_context := ctx

(** A signal holds a value and a set of subscribers *)
type 'a t = {
  mutable value : 'a;
  mutable subscribers : (unit -> unit) list;
}

let create initial =
  let signal = { value = initial; subscribers = [] } in
  let setter new_value =
    signal.value <- new_value;
    (* Notify all subscribers *)
    List.iter (fun notify -> notify ()) signal.subscribers
  in
  (signal, setter)

let peek signal = signal.value

let get signal =
  (* If there's a tracking context, register as subscriber *)
  (match !tracking_context with
   | Some notify ->
     if not (List.memq notify signal.subscribers) then
       signal.subscribers <- notify :: signal.subscribers
   | None -> ());
  signal.value

let set signal new_value =
  signal.value <- new_value;
  List.iter (fun notify -> notify ()) signal.subscribers

let update signal f =
  set signal (f signal.value)

let subscribe signal notify =
  signal.subscribers <- notify :: signal.subscribers;
  (* Return unsubscribe function *)
  fun () ->
    signal.subscribers <- List.filter (fun s -> s != notify) signal.subscribers

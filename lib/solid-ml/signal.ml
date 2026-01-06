(** Reactive signals with automatic dependency tracking.
    
    Signals are reactive values that track dependencies automatically.
    When a signal is read inside a computation (effect or memo), the
    computation is registered as an observer and will be notified when
    the signal changes.
    
    This implementation matches SolidJS's signal architecture with
    bidirectional links and O(1) cleanup.
*)

(** A signal holds a reactive value *)
type 'a t = 'a Reactive.signal_state

(** Create a signal with an initial value.
    
    By default, uses structural equality (=) to determine if the value
    has changed. Updates are skipped if the new value equals the old.
    
    @param equals Custom equality function (default: structural equality)
    @param initial The initial value *)
let create ?(equals = (=)) initial =
  let signal : 'a t = {
    Reactive.value = initial;
    observers = [||];
    observer_slots = [||];
    observers_len = 0;
    comparator = Some equals;
  } in
  let setter new_value =
    Reactive.write_signal signal new_value
  in
  (signal, setter)

(** Create a signal with a custom equality function *)
let create_eq ~equals initial = create ~equals initial

(** Create a signal using physical equality (==).
    
    Use this for signals holding mutable values or when you want
    updates on every set regardless of value. *)
let create_physical initial = create ~equals:(==) initial

(** Read the signal value without tracking.
    
    This will not register any dependency. Use when you need the
    value but don't want the current computation to re-run when
    this signal changes. *)
let peek (signal : 'a t) : 'a = signal.Reactive.value

(** Read the signal value with tracking.
    
    If called inside a computation (effect/memo), registers the
    computation as an observer. The computation will re-run when
    this signal changes. *)
let get signal = Reactive.read_signal signal

(** Set the signal value.
    
    If the new value is different (according to the equality function),
    notifies all observers and triggers their re-execution. *)
let set signal new_value =
  Reactive.write_signal signal new_value

(** Update the signal value using a function.
    
    Equivalent to [set signal (f (peek signal))]. *)
let update (signal : 'a t) f =
  set signal (f (peek signal))

(** Subscribe to signal changes.
    
    The callback is called whenever the signal value changes.
    Returns an unsubscribe function.
    
    Note: For most use cases, prefer using [Effect.create] instead,
    which provides automatic cleanup and better integration with
    the ownership system. *)
let subscribe (signal : 'a t) callback =
  (* Create a minimal effect just for this subscription *)
  let disposed = ref false in
  
  let comp : Reactive.computation = {
    Reactive.fn = Some (fun _ -> callback (); Obj.repr ());
    state = Reactive.Clean;  (* Start Clean so it can be triggered *)
    sources = [||];
    source_slots = [||];
    source_kinds = [||];
    sources_len = 0;
    value = Obj.repr ();
    updated_at = 0;
    pure = false;
    user = true;
    owned = [];
    cleanups = [];
    owner = None;
    context = [];
    memo_observers = None;
    memo_observer_slots = None;
    memo_observers_len = 0;
    memo_comparator = None;
  } in
  
  (* Manually add to signal's observers *)
  if signal.Reactive.observers_len = 0 then begin
    signal.Reactive.observers <- Array.make 4 comp;
    signal.Reactive.observer_slots <- Array.make 4 0;
    signal.Reactive.observers_len <- 1
  end else begin
    let len = signal.Reactive.observers_len in
    if len >= Array.length signal.Reactive.observers then begin
      let new_observers = Array.make (len * 2) comp in
      let new_slots = Array.make (len * 2) 0 in
      Array.blit signal.Reactive.observers 0 new_observers 0 len;
      Array.blit signal.Reactive.observer_slots 0 new_slots 0 len;
      signal.Reactive.observers <- new_observers;
      signal.Reactive.observer_slots <- new_slots
    end;
    Array.set signal.Reactive.observers len comp;
    Array.set signal.Reactive.observer_slots len 0;
    signal.Reactive.observers_len <- len + 1
  end;
  
  (* Return unsubscribe function *)
  fun () ->
    if not !disposed then begin
      disposed := true;
      (* Remove from observers - find and swap-pop *)
      let rec find_and_remove i =
        if i >= signal.Reactive.observers_len then ()
        else if Array.get signal.Reactive.observers i == comp then begin
          (* Swap with last *)
          let last = signal.Reactive.observers_len - 1 in
          if i < last then begin
            Array.set signal.Reactive.observers i (Array.get signal.Reactive.observers last);
            Array.set signal.Reactive.observer_slots i (Array.get signal.Reactive.observer_slots last)
          end;
          signal.Reactive.observers_len <- last
        end else
          find_and_remove (i + 1)
      in
      find_and_remove 0
    end

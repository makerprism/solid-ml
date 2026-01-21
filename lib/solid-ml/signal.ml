(** Reactive signals with automatic dependency tracking.
    
    Signals are reactive values that track dependencies automatically.
    When a signal is read inside a computation (effect or memo), the
    computation is registered as an observer and will be notified when
    the signal changes.
*)

(** A signal holds a reactive value *)
type 'a t = 'a Reactive.signal

type token = Runtime.token

(** Create a signal with an initial value.
    
    By default, uses structural equality (=) to determine if the value
    has changed. Updates are skipped if the new value equals the old. *)
let create (_token : token) ?equals initial =
  let signal = Reactive.create_signal ?equals initial in
  let setter new_value = Reactive.write_signal signal new_value in
  (signal, setter)

(** Create a signal with a custom equality function *)
let create_eq token ~equals initial = create token ~equals initial

(** Create a signal using physical equality (==). *)
let create_physical token initial = create token ~equals:(==) initial

(** Read the signal value without tracking. *)
let peek signal = Reactive.peek_signal signal

(** Read the signal value with tracking. *)
let get signal = Reactive.read_signal signal

(** Set the signal value. *)
let set signal new_value = Reactive.write_signal signal new_value

(** Update the signal value using a function. *)
let update signal f = set signal (f (peek signal))

(** Subscribe to signal changes.
    Returns an unsubscribe function.
    
    Note: For most use cases, prefer using [Effect.create] instead. *)
let subscribe (_token : token) (signal : 'a t) callback =
  (* Create a minimal effect just for this subscription *)
  let disposed = ref false in
  let internal = Reactive.Internal.Types.signal_to_internal signal in
  
  let comp : Reactive.computation = Reactive.Internal.Types.{
    fn = Some (fun _ -> callback (); Obj.repr ());
    state = Clean;
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
    child_owners = [];
    memo_observers = None;
    memo_observer_slots = None;
    memo_observers_len = 0;
    memo_comparator = None;
  } in
  
  (* Manually add to signal's observers *)
  let open Reactive.Internal.Types in
  if internal.observers_len = 0 then begin
    internal.observers <- Array.make 4 comp;
    internal.observer_slots <- Array.make 4 0;
    internal.observers_len <- 1
  end else begin
    let len = internal.observers_len in
    if len >= Array.length internal.observers then begin
      let new_observers = Array.make (len * 2) comp in
      let new_slots = Array.make (len * 2) 0 in
      Array.blit internal.observers 0 new_observers 0 len;
      Array.blit internal.observer_slots 0 new_slots 0 len;
      internal.observers <- new_observers;
      internal.observer_slots <- new_slots
    end;
    Array.set internal.observers len comp;
    Array.set internal.observer_slots len 0;
    internal.observers_len <- len + 1
  end;
  
  (* Return unsubscribe function *)
  fun () ->
    if not !disposed then begin
      disposed := true;
      let rec find_and_remove i =
        if i >= internal.observers_len then ()
        else if Array.get internal.observers i == comp then begin
          let last = internal.observers_len - 1 in
          if i < last then begin
            Array.set internal.observers i (Array.get internal.observers last);
            Array.set internal.observer_slots i (Array.get internal.observer_slots last)
          end;
          internal.observers_len <- last
        end else
          find_and_remove (i + 1)
      in
      find_and_remove 0
    end

module Unsafe = struct
  type 'a t = 'a Reactive.signal

  let create ?equals initial =
    let signal = Reactive.create_signal ?equals initial in
    let setter new_value = Reactive.write_signal signal new_value in
    (signal, setter)

  let create_eq ~equals initial = create ~equals initial

  let create_physical initial = create ~equals:(==) initial

  let get signal = Reactive.read_signal signal
  let peek signal = Reactive.peek_signal signal
  let set signal value = Reactive.write_signal signal value
  let update signal f = set signal (f (peek signal))

  let subscribe (signal : 'a t) callback =
    let disposed = ref false in
    let internal = Reactive.Internal.Types.signal_to_internal signal in

    let comp : Reactive.computation = Reactive.Internal.Types.{
      fn = Some (fun _ -> callback (); Obj.repr ());
      state = Clean;
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
      child_owners = [];
      memo_observers = None;
      memo_observer_slots = None;
      memo_observers_len = 0;
      memo_comparator = None;
    } in

    let open Reactive.Internal.Types in
    if internal.observers_len = 0 then begin
      internal.observers <- Array.make 4 comp;
      internal.observer_slots <- Array.make 4 0;
      internal.observers_len <- 1
    end else begin
      let len = internal.observers_len in
      if len >= Array.length internal.observers then begin
        let new_observers = Array.make (len * 2) comp in
        let new_slots = Array.make (len * 2) 0 in
        Array.blit internal.observers 0 new_observers 0 len;
        Array.blit internal.observer_slots 0 new_slots 0 len;
        internal.observers <- new_observers;
        internal.observer_slots <- new_slots
      end;
      Array.set internal.observers len comp;
      Array.set internal.observer_slots len 0;
      internal.observers_len <- len + 1
    end;

    fun () ->
      if not !disposed then begin
        disposed := true;
        let rec find_and_remove i =
          if i >= internal.observers_len then ()
          else if Array.get internal.observers i == comp then begin
            let last = internal.observers_len - 1 in
            if i < last then begin
              Array.set internal.observers i (Array.get internal.observers last);
              Array.set internal.observer_slots i (Array.get internal.observer_slots last)
            end;
            internal.observers_len <- last
          end else
            find_and_remove (i + 1)
        in
        find_and_remove 0
      end
end

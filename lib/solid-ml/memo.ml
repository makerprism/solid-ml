(** Memoized derived values with automatic dependency tracking.
    
    Memos are computed values that cache their result and only
    recompute when their dependencies change. Unlike effects,
    memos are lazy - they only compute when read.
    
    This implementation matches SolidJS's memo architecture:
    - Memos are computations that can also be observed
    - They have their own observers array (like signals)
    - They propagate updates downstream when their value changes
*)

(** A memo is a computation that can be read like a signal *)
type 'a t = {
  computation: Reactive.computation;
  mutable cached_value: 'a;
  mutable has_value: bool;  (** Has the memo been computed at least once? *)
  equals: 'a -> 'a -> bool;
}

(** Read a memo's value, tracking the dependency.
    
    If the memo is stale, it will be recomputed first.
    If called inside a computation, registers that computation
    as an observer of this memo. *)
let get (memo: 'a t) : 'a =
  let rt = Reactive.get_runtime () in
  let comp = memo.computation in
  
  (* If stale, recompute first *)
  if comp.state = Reactive.Stale then begin
    Reactive.clean_node comp;
    Reactive.run_computation comp;
    comp.state <- Reactive.Clean;
    memo.cached_value <- Obj.obj comp.value
  end else if comp.state = Reactive.Pending then begin
    (* Check if we actually need to update *)
    Reactive.look_upstream comp;
    if comp.state = Reactive.Stale then begin
      Reactive.clean_node comp;
      Reactive.run_computation comp;
      comp.state <- Reactive.Clean;
      memo.cached_value <- Obj.obj comp.value
    end
  end;
  
  (* Track dependency if there's a listener *)
  begin match rt.listener with
  | Some listener ->
    (* Add this memo to listener's sources *)
    let s_slot = comp.memo_observers_len in
    
    if listener.sources_len = 0 then begin
      listener.sources <- Array.make 4 (Obj.repr comp);
      listener.source_slots <- Array.make 4 s_slot;
      listener.source_kinds <- Array.make 4 Reactive.Memo_source;
      listener.sources_len <- 1
    end else begin
      let len = listener.sources_len in
      if len >= Array.length listener.sources then begin
        let new_sources = Array.make (len * 2) (Obj.repr comp) in
        let new_slots = Array.make (len * 2) 0 in
        let new_kinds = Array.make (len * 2) Reactive.Memo_source in
        Array.blit listener.sources 0 new_sources 0 len;
        Array.blit listener.source_slots 0 new_slots 0 len;
        Array.blit listener.source_kinds 0 new_kinds 0 len;
        listener.sources <- new_sources;
        listener.source_slots <- new_slots;
        listener.source_kinds <- new_kinds
      end;
      Array.set listener.sources len (Obj.repr comp);
      Array.set listener.source_slots len s_slot;
      Array.set listener.source_kinds len Reactive.Memo_source;
      listener.sources_len <- len + 1
    end;
    
    (* Add listener to memo's observers *)
    let observers = match comp.memo_observers with
      | Some obs -> obs
      | None ->
        let obs = Array.make 4 listener in
        comp.memo_observers <- Some obs;
        comp.memo_observer_slots <- Some (Array.make 4 0);
        obs
    in
    let slots = match comp.memo_observer_slots with
      | Some s -> s
      | None -> failwith "memo_observer_slots should exist"
    in
    
    if comp.memo_observers_len >= Array.length observers then begin
      let new_obs = Array.make (comp.memo_observers_len * 2) listener in
      let new_slots = Array.make (comp.memo_observers_len * 2) 0 in
      Array.blit observers 0 new_obs 0 comp.memo_observers_len;
      Array.blit slots 0 new_slots 0 comp.memo_observers_len;
      comp.memo_observers <- Some new_obs;
      comp.memo_observer_slots <- Some new_slots
    end;
    
    let obs = match comp.memo_observers with Some o -> o | None -> observers in
    let slt = match comp.memo_observer_slots with Some s -> s | None -> slots in
    Array.set obs comp.memo_observers_len listener;
    Array.set slt comp.memo_observers_len (listener.sources_len - 1);
    comp.memo_observers_len <- comp.memo_observers_len + 1
    
  | None -> ()
  end;
  
  memo.cached_value

(** Create a memoized value.
    
    The function is called lazily when the memo is first read,
    and recomputed whenever its dependencies change.
    
    @param equals Custom equality function (default: structural equality)
    @param fn The computation function *)
let create ?(equals = (=)) fn =
  (* Create computation but don't run it yet - memos are lazy *)
  let memo_ref = ref None in
  
  (* We need a reference to the computation for the fn to access memo_observers *)
  let comp_ref = ref None in
  
  let comp = Reactive.create_computation
    ~fn:(fun _prev_value ->
      let new_value = fn () in
      (* Check if value actually changed *)
      begin match !memo_ref, !comp_ref with
      | Some memo, Some the_comp ->
        (* Only notify downstream if value changed AND we have a previous value *)
        if memo.has_value && not (memo.equals memo.cached_value new_value) then begin
          memo.cached_value <- new_value;
          (* Mark downstream observers as Stale *)
          let rt = Reactive.get_runtime () in
          let len = the_comp.Reactive.memo_observers_len in
          begin match the_comp.Reactive.memo_observers with
          | Some observers when len > 0 ->
            for i = 0 to len - 1 do
              let o = Array.get observers i in
              if o.Reactive.state = Reactive.Clean then begin
                o.Reactive.state <- Reactive.Stale;
                if o.Reactive.pure then
                  rt.Reactive.updates <- o :: rt.Reactive.updates
                else
                  rt.Reactive.effects <- o :: rt.Reactive.effects
              end else if o.Reactive.state = Reactive.Pending then begin
                o.Reactive.state <- Reactive.Stale
              end
            done
          | _ -> ()
          end
        end else begin
          memo.cached_value <- new_value;
          memo.has_value <- true
        end
      | _ -> ()
      end;
      Obj.repr new_value
    )
    ~init:(Obj.repr ())
    ~pure:true
    ~initial_state:Reactive.Stale  (* Start stale so first read computes *)
  in
  
  comp_ref := Some comp;
  
  let memo = {
    computation = comp;
    cached_value = Obj.magic ();  (* Will be set on first read *)
    has_value = false;
    equals;
  } in
  memo_ref := Some memo;
  
  (* Compute immediately (eager like SolidJS) *)
  let _ = get memo in
  
  memo

(** Create a memoized value with a custom equality function *)
let create_with_equals ~eq fn = create ~equals:eq fn

(** Read memo without tracking (peek at cached value).
    Note: This may return a stale value. *)
let peek memo = memo.cached_value

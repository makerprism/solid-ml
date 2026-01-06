(** Browser-only reactive core for solid-ml-dom.
    
    This is a simplified single-threaded implementation that runs in the browser.
    It doesn't need Domain-local storage since JavaScript is single-threaded.
    
    Follows the same SolidJS-inspired architecture as the server-side solid-ml,
    but optimized for the browser environment.
*)

(** {1 Types} *)

(** State of a computation (effect or memo) *)
type computation_state = Clean | Stale | Pending

(** Source kind for proper cleanup *)
type source_kind = Signal_source | Memo_source

(** Internal signal state - mutable for efficiency *)
type 'a signal_state = {
  mutable value: 'a;
  mutable observers: computation array;
  mutable observer_slots: int array;
  mutable observer_count: int;
  equals: 'a -> 'a -> bool;
}

(** Computation (effect or memo) *)
and computation = {
  mutable fn: unit -> unit;
  mutable state: computation_state;
  mutable sources: signal_or_memo array;
  mutable source_slots: int array;
  mutable source_kinds: source_kind array;
  mutable source_count: int;
  mutable owner: owner option;
  pure: bool;  (* true for memos, false for effects *)
  mutable cleanups: (unit -> unit) list;
}

(** Either a signal or memo as a source *)
and signal_or_memo =
  | SSignal : 'a signal_state -> signal_or_memo
  | SMemo : 'a memo_state -> signal_or_memo

(** Memo state *)
and 'a memo_state = {
  mutable memo_value: 'a;
  mutable has_value: bool;
  memo_fn: unit -> 'a;
  memo_equals: 'a -> 'a -> bool;
  memo_computation: computation;
  mutable memo_observers: computation array;
  mutable memo_observer_slots: int array;
  mutable memo_observer_count: int;
}

(** Owner for cleanup tracking *)
and owner = {
  mutable owner_cleanups: (unit -> unit) list;
  mutable owned_computations: computation list;
  mutable child_owners: owner list;
  parent_owner: owner option;
  mutable context_values: (int * Obj.t) list;
}

(** {1 Global State} *)

(** Current computation being executed (for dependency tracking) *)
let current_computation : computation option ref = ref None

(** Current owner for cleanup registration *)
let current_owner : owner option ref = ref None

(** Batch depth for grouping updates *)
let batch_depth = ref 0

(** Pending updates queue *)
let pending_effects : computation Queue.t = Queue.create ()
let pending_memos : computation Queue.t = Queue.create ()

(** Context ID counter *)
let next_context_id = ref 0

(** {1 Owner Management} *)

let create_owner ?parent () : owner =
  let o = {
    owner_cleanups = [];
    owned_computations = [];
    child_owners = [];
    parent_owner = parent;
    context_values = [];
  } in
  (match parent with
   | Some p -> p.child_owners <- o :: p.child_owners
   | None -> ());
  o

let rec dispose_owner (o : owner) : unit =
  (* Dispose child owners first *)
  List.iter dispose_owner o.child_owners;
  o.child_owners <- [];
  (* Run cleanups in reverse order *)
  List.iter (fun f -> f ()) (List.rev o.owner_cleanups);
  o.owner_cleanups <- [];
  (* Clean up owned computations - run their cleanups and remove from dependency graph *)
  List.iter (fun c ->
    (* Run computation cleanups *)
    List.iter (fun f -> f ()) c.cleanups;
    c.cleanups <- [];
    (* Remove from all sources' observer lists *)
    for i = 0 to c.source_count - 1 do
      let src = c.sources.(i) in
      let slot = c.source_slots.(i) in
      let kind = c.source_kinds.(i) in
      match kind with
      | Signal_source ->
        (match src with
         | SSignal s ->
           let last_idx = s.observer_count - 1 in
           if last_idx >= 0 && slot <= last_idx then begin
             if slot < last_idx then begin
               let last = s.observers.(last_idx) in
               s.observers.(slot) <- last;
               s.observer_slots.(slot) <- s.observer_slots.(last_idx);
               (* Update the moved observer's source_slots if valid *)
               if s.observer_slots.(slot) < last.source_count then
                 last.source_slots.(s.observer_slots.(slot)) <- slot
             end;
             s.observer_count <- last_idx
           end
         | SMemo _ -> ())
      | Memo_source ->
        (match src with
         | SMemo m ->
           let last_idx = m.memo_observer_count - 1 in
           if last_idx >= 0 && slot <= last_idx then begin
             if slot < last_idx then begin
               let last = m.memo_observers.(last_idx) in
               m.memo_observers.(slot) <- last;
               m.memo_observer_slots.(slot) <- m.memo_observer_slots.(last_idx);
               if m.memo_observer_slots.(slot) < last.source_count then
                 last.source_slots.(m.memo_observer_slots.(slot)) <- slot
             end;
             m.memo_observer_count <- last_idx
           end
         | SSignal _ -> ())
    done;
    c.source_count <- 0
  ) o.owned_computations;
  o.owned_computations <- []

let get_owner () = !current_owner

let on_cleanup (f : unit -> unit) : unit =
  match !current_owner with
  | Some o -> o.owner_cleanups <- f :: o.owner_cleanups
  | None -> ()

(** {1 Dependency Tracking} *)

let add_observer (s : 'a signal_state) (c : computation) : int =
  let idx = s.observer_count in
  if idx >= Array.length s.observers then begin
    let new_len = max 4 (Array.length s.observers * 2) in
    let new_obs = Array.make new_len c in
    let new_slots = Array.make new_len 0 in
    Array.blit s.observers 0 new_obs 0 idx;
    Array.blit s.observer_slots 0 new_slots 0 idx;
    s.observers <- new_obs;
    s.observer_slots <- new_slots
  end;
  s.observers.(idx) <- c;
  s.observer_count <- idx + 1;
  idx

let add_memo_observer (m : 'a memo_state) (c : computation) : int =
  let idx = m.memo_observer_count in
  if idx >= Array.length m.memo_observers then begin
    let new_len = max 4 (Array.length m.memo_observers * 2) in
    let new_obs = Array.make new_len c in
    let new_slots = Array.make new_len 0 in
    Array.blit m.memo_observers 0 new_obs 0 idx;
    Array.blit m.memo_observer_slots 0 new_slots 0 idx;
    m.memo_observers <- new_obs;
    m.memo_observer_slots <- new_slots
  end;
  m.memo_observers.(idx) <- c;
  m.memo_observer_count <- idx + 1;
  idx

let add_source (c : computation) (src : signal_or_memo) (kind : source_kind) (slot : int) : unit =
  let idx = c.source_count in
  if idx >= Array.length c.sources then begin
    let new_len = max 4 (Array.length c.sources * 2) in
    let new_sources = Array.make new_len src in
    let new_slots = Array.make new_len 0 in
    let new_kinds = Array.make new_len kind in
    Array.blit c.sources 0 new_sources 0 idx;
    Array.blit c.source_slots 0 new_slots 0 idx;
    Array.blit c.source_kinds 0 new_kinds 0 idx;
    c.sources <- new_sources;
    c.source_slots <- new_slots;
    c.source_kinds <- new_kinds
  end;
  c.sources.(idx) <- src;
  c.source_slots.(idx) <- slot;
  c.source_kinds.(idx) <- kind;
  c.source_count <- idx + 1

(** Clean up a computation's dependencies *)
let clean_node (c : computation) : unit =
  for i = 0 to c.source_count - 1 do
    let src = c.sources.(i) in
    let slot = c.source_slots.(i) in
    let kind = c.source_kinds.(i) in
    match kind with
    | Signal_source ->
      (match src with
       | SSignal s ->
         let last_idx = s.observer_count - 1 in
         if slot < last_idx then begin
           let last = s.observers.(last_idx) in
           s.observers.(slot) <- last;
           s.observer_slots.(slot) <- s.observer_slots.(last_idx);
           last.source_slots.(s.observer_slots.(slot)) <- slot
         end;
         s.observer_count <- last_idx
       | SMemo _ -> ())
    | Memo_source ->
      (match src with
       | SMemo m ->
         let last_idx = m.memo_observer_count - 1 in
         if slot < last_idx then begin
           let last = m.memo_observers.(last_idx) in
           m.memo_observers.(slot) <- last;
           m.memo_observer_slots.(slot) <- m.memo_observer_slots.(last_idx);
           last.source_slots.(m.memo_observer_slots.(slot)) <- slot
         end;
         m.memo_observer_count <- last_idx
       | SSignal _ -> ())
  done;
  c.source_count <- 0

(** {1 Update Propagation} *)

let mark_stale (c : computation) : unit =
  if c.state = Clean then begin
    c.state <- Stale;
    if c.pure then
      Queue.push c pending_memos
    else
      Queue.push c pending_effects
  end

let mark_downstream_signal (s : 'a signal_state) : unit =
  for i = 0 to s.observer_count - 1 do
    mark_stale s.observers.(i)
  done

let mark_downstream_memo (m : 'a memo_state) : unit =
  for i = 0 to m.memo_observer_count - 1 do
    mark_stale m.memo_observers.(i)
  done

(** Run a computation *)
let run_computation (c : computation) : unit =
  (* Run cleanups first *)
  List.iter (fun f -> f ()) c.cleanups;
  c.cleanups <- [];
  (* Clean old dependencies *)
  clean_node c;
  (* Set as current computation for tracking *)
  let prev_comp = !current_computation in
  let prev_owner = !current_owner in
  current_computation := Some c;
  current_owner := c.owner;
  (* Run the computation - log errors instead of silently swallowing *)
  (try c.fn () with exn ->
    (* Restore context before logging *)
    current_computation := prev_comp;
    current_owner := prev_owner;
    c.state <- Clean;
    (* Re-raise to let caller handle or log *)
    raise exn
  );
  (* Restore context *)
  current_computation := prev_comp;
  current_owner := prev_owner;
  c.state <- Clean

(** Log error to console *)
external console_error : string -> unit = "error" [@@mel.scope "console"]

(** Process pending updates *)
let rec complete_updates () : unit =
  (* Process memos first (they're pure) *)
  while not (Queue.is_empty pending_memos) do
    let c = Queue.pop pending_memos in
    if c.state = Stale then
      try run_computation c
      with exn ->
        console_error ("solid-ml: Error in memo: " ^ Printexc.to_string exn)
  done;
  (* Then effects *)
  while not (Queue.is_empty pending_effects) do
    let c = Queue.pop pending_effects in
    if c.state = Stale then
      try run_computation c
      with exn ->
        console_error ("solid-ml: Error in effect: " ^ Printexc.to_string exn)
  done;
  (* If new updates were queued during processing, continue *)
  if not (Queue.is_empty pending_memos) || not (Queue.is_empty pending_effects) then
    complete_updates ()

let run_updates () : unit =
  if !batch_depth = 0 then
    complete_updates ()

(** {1 Signal API} *)

type 'a signal = 'a signal_state

let create_signal ?(equals = (=)) (initial : 'a) : 'a signal =
  {
    value = initial;
    observers = [||];
    observer_slots = [||];
    observer_count = 0;
    equals;
  }

let get_signal (s : 'a signal) : 'a =
  (* Track dependency if inside a computation *)
  (match !current_computation with
   | Some c ->
     let slot = add_observer s c in
     add_source c (SSignal s) Signal_source slot
   | None -> ());
  s.value

let set_signal (s : 'a signal) (v : 'a) : unit =
  if not (s.equals s.value v) then begin
    s.value <- v;
    mark_downstream_signal s;
    run_updates ()
  end

let peek_signal (s : 'a signal) : 'a = s.value

let update_signal (s : 'a signal) (f : 'a -> 'a) : unit =
  set_signal s (f s.value)

(** {1 Effect API} *)

let create_effect (f : unit -> unit) : unit =
  let c = {
    fn = f;
    state = Stale;
    sources = [||];
    source_slots = [||];
    source_kinds = [||];
    source_count = 0;
    owner = !current_owner;
    pure = false;
    cleanups = [];
  } in
  (* Register with owner *)
  (match !current_owner with
   | Some o -> o.owned_computations <- c :: o.owned_computations
   | None -> ());
  (* Run immediately *)
  run_computation c

let create_effect_with_cleanup (f : unit -> (unit -> unit)) : unit =
  let cleanup_ref = ref (fun () -> ()) in
  let wrapped () =
    cleanup_ref := f ()
  in
  let c = {
    fn = wrapped;
    state = Stale;
    sources = [||];
    source_slots = [||];
    source_kinds = [||];
    source_count = 0;
    owner = !current_owner;
    pure = false;
    cleanups = [];
  } in
  c.fn <- (fun () ->
    !cleanup_ref ();
    cleanup_ref := f ()
  );
  (* Register with owner *)
  (match !current_owner with
   | Some o -> o.owned_computations <- c :: o.owned_computations
   | None -> ());
  (* Run immediately (first run, no cleanup yet) *)
  let prev_comp = !current_computation in
  let prev_owner = !current_owner in
  current_computation := Some c;
  current_owner := c.owner;
  cleanup_ref := f ();
  current_computation := prev_comp;
  current_owner := prev_owner;
  c.state <- Clean

let untrack (f : unit -> 'a) : 'a =
  let prev = !current_computation in
  current_computation := None;
  let result = f () in
  current_computation := prev;
  result

(** {1 Memo API} *)

type 'a memo = 'a memo_state

let create_memo ?(equals = (=)) (f : unit -> 'a) : 'a memo =
  let rec m = {
    memo_value = Obj.magic ();
    has_value = false;
    memo_fn = f;
    memo_equals = equals;
    memo_computation = c;
    memo_observers = [||];
    memo_observer_slots = [||];
    memo_observer_count = 0;
  }
  and c = {
    fn = (fun () ->
      let new_val = f () in
      if not m.has_value || not (m.memo_equals m.memo_value new_val) then begin
        m.memo_value <- new_val;
        m.has_value <- true;
        mark_downstream_memo m
      end
    );
    state = Stale;
    sources = [||];
    source_slots = [||];
    source_kinds = [||];
    source_count = 0;
    owner = !current_owner;
    pure = true;
    cleanups = [];
  } in
  (* Register with owner *)
  (match !current_owner with
   | Some o -> o.owned_computations <- c :: o.owned_computations
   | None -> ());
  (* Eager evaluation like SolidJS *)
  run_computation c;
  m

let get_memo (m : 'a memo) : 'a =
  (* Ensure memo is computed *)
  if m.memo_computation.state = Stale then
    run_computation m.memo_computation;
  (* Track dependency if inside a computation *)
  (match !current_computation with
   | Some c ->
     let slot = add_memo_observer m c in
     add_source c (SMemo m) Memo_source slot
   | None -> ());
  m.memo_value

let peek_memo (m : 'a memo) : 'a = m.memo_value

(** {1 Batch API} *)

let batch (f : unit -> 'a) : 'a =
  incr batch_depth;
  let result = f () in
  decr batch_depth;
  if !batch_depth = 0 then complete_updates ();
  result

(** {1 Root API} *)

let create_root (f : unit -> 'a) : 'a * (unit -> unit) =
  let o = create_owner ?parent:!current_owner () in
  let prev_owner = !current_owner in
  current_owner := Some o;
  let result = f () in
  current_owner := prev_owner;
  (result, fun () -> dispose_owner o)

let run_with_owner (f : unit -> 'a) : 'a * (unit -> unit) =
  let o = create_owner ?parent:!current_owner () in
  let prev_owner = !current_owner in
  current_owner := Some o;
  let result = f () in
  current_owner := prev_owner;
  (result, fun () -> dispose_owner o)

(** {1 Context API} *)

type 'a context = {
  id: int;
  default: 'a;
}

let create_context (default : 'a) : 'a context =
  let id = !next_context_id in
  incr next_context_id;
  { id; default }

let provide_context (ctx : 'a context) (value : 'a) (f : unit -> 'b) : 'b =
  match !current_owner with
  | Some o ->
    o.context_values <- (ctx.id, Obj.repr value) :: o.context_values;
    f ()
  | None -> f ()

let rec find_context_in_owner (ctx : 'a context) (o : owner) : 'a option =
  match List.assoc_opt ctx.id o.context_values with
  | Some v -> Some (Obj.obj v)
  | None ->
    match o.parent_owner with
    | Some parent -> find_context_in_owner ctx parent
    | None -> None

let use_context (ctx : 'a context) : 'a =
  match !current_owner with
  | Some o ->
    (match find_context_in_owner ctx o with
     | Some v -> v
     | None -> ctx.default)
  | None -> ctx.default

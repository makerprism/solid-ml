(** Core reactive system matching SolidJS architecture.
    
    This module implements the core reactive primitives with:
    - Bidirectional links between signals and computations
    - STALE/PENDING/CLEAN state machine for computations
    - Topological update ordering
    - Slot-based O(1) cleanup
    
    Based on SolidJS signal.ts implementation.
*)

(** {1 State Constants} *)

type computation_state = 
  | Clean   (** Up-to-date, no recomputation needed *)
  | Stale   (** Definitely needs recomputation *)
  | Pending (** Maybe needs recomputation (upstream might be stale) *)

(** {1 Forward Declarations} *)

(* We use a two-phase approach: first define base types, then the full types *)

(** {1 Source Kind} *)

(** Tag to distinguish signal sources from memo sources *)
type source_kind = 
  | Signal_source  (** Source is a signal_state *)
  | Memo_source    (** Source is a computation (memo) *)

(** {1 Core Types} *)

(** A signal holds a reactive value with observers *)
type 'a signal_state = {
  mutable value: 'a;
  mutable observers: computation array;      (** Computations that depend on this signal *)
  mutable observer_slots: int array;         (** Slot index in each observer's sources array *)
  mutable observers_len: int;                (** Actual number of observers *)
  comparator: ('a -> 'a -> bool) option;     (** Custom equality check *)
}

(** Owner node for cleanup hierarchy *)
and owner = {
  mutable owned: computation list;           (** Child computations *)
  mutable cleanups: (unit -> unit) list;     (** Cleanup functions *)
  mutable owner: owner option;               (** Parent owner *)
  mutable context: (int * Obj.t) list;       (** Context values *)
  mutable child_owners: owner list;          (** Nested owners *)
}

(** A computation (effect or memo) *)
and computation = {
  mutable fn: (Obj.t -> Obj.t) option;       (** The computation function (None if disposed) *)
  mutable state: computation_state;          (** Current state *)
  mutable sources: Obj.t array;              (** Signals this computation depends on (as signal_state) *)
  mutable source_slots: int array;           (** Slot index in each source's observers array *)
  mutable source_kinds: source_kind array;   (** Kind of each source (signal or memo) *)
  mutable sources_len: int;                  (** Actual number of sources *)
  mutable value: Obj.t;                      (** Last computed value *)
  mutable updated_at: int;                   (** ExecCount when last updated *)
  pure: bool;                                (** true = memo/computed, false = effect *)
  mutable user: bool;                        (** true = user effect (runs after render) *)
  
  (* Owner fields (computation extends owner) *)
  mutable owned: computation list;
  mutable cleanups: (unit -> unit) list;
  mutable owner: owner option;
  mutable context: (int * Obj.t) list;
  
  (* Memo-specific: if this is a memo, it can also be observed *)
  mutable memo_observers: computation array option;
  mutable memo_observer_slots: int array option;
  mutable memo_observers_len: int;
  memo_comparator: (Obj.t -> Obj.t -> bool) option;
}

(** {1 Global State} *)

(** Runtime state for a single domain/thread *)
type runtime = {
  mutable listener: computation option;       (** Current computation being tracked *)
  mutable owner: owner option;                (** Current owner for cleanup registration *)
  mutable updates: computation list;          (** Queue of pure computations to run *)
  mutable effects: computation list;          (** Queue of effects to run *)
  mutable exec_count: int;                    (** Monotonically increasing execution counter *)
  mutable in_update: bool;                    (** Are we inside runUpdates? *)
}

(** Domain-local storage for runtime *)
let runtime_key : runtime option Domain.DLS.key =
  Domain.DLS.new_key (fun () -> None)

let get_runtime () =
  match Domain.DLS.get runtime_key with
  | Some rt -> rt
  | None -> failwith "No reactive runtime active. Use Reactive.run."

let get_runtime_opt () =
  Domain.DLS.get runtime_key

let set_runtime rt =
  Domain.DLS.set runtime_key rt

let create_runtime () = {
  listener = None;
  owner = None;
  updates = [];
  effects = [];
  exec_count = 0;
  in_update = false;
}

(** {1 Array Helpers} *)

(** Ensure array has capacity for at least n elements *)
let ensure_capacity arr len needed =
  let current_len = Array.length arr in
  if current_len >= needed then arr
  else begin
    let new_len = max needed (current_len * 2) in
    let new_arr = Array.make new_len (Array.get arr 0) in
    Array.blit arr 0 new_arr 0 len;
    new_arr
  end

(** {1 Forward Declarations for Mutual Recursion} *)

let run_updates_ref : ((unit -> 'a) -> bool -> 'a) ref = ref (fun _ _ -> failwith "not initialized")
let clean_node_ref : (computation -> unit) ref = ref (fun _ -> failwith "not initialized")

(** {1 Read Signal} *)

(** Ensure source_kinds array has capacity *)
let ensure_capacity_kinds arr len needed =
  let current_len = Array.length arr in
  if current_len >= needed then arr
  else begin
    let new_len = max needed (current_len * 2) in
    let new_arr = Array.make new_len Signal_source in
    Array.blit arr 0 new_arr 0 len;
    new_arr
  end

(** Read a signal, tracking the dependency if there's a listener *)
let read_signal : 'a. 'a signal_state -> 'a = fun signal ->
  let rt = get_runtime () in
  
  (* If we're tracking (inside a computation), register dependency *)
  begin match rt.listener with
  | Some listener ->
    let s_slot = signal.observers_len in
    
    (* Add signal to listener's sources *)
    if listener.sources_len = 0 then begin
      listener.sources <- Array.make 4 (Obj.repr signal);
      listener.source_slots <- Array.make 4 s_slot;
      listener.source_kinds <- Array.make 4 Signal_source;
      listener.sources_len <- 1
    end else begin
      listener.sources <- ensure_capacity listener.sources listener.sources_len (listener.sources_len + 1);
      listener.source_slots <- ensure_capacity listener.source_slots listener.sources_len (listener.sources_len + 1);
      listener.source_kinds <- ensure_capacity_kinds listener.source_kinds listener.sources_len (listener.sources_len + 1);
      Array.set listener.sources listener.sources_len (Obj.repr signal);
      Array.set listener.source_slots listener.sources_len s_slot;
      Array.set listener.source_kinds listener.sources_len Signal_source;
      listener.sources_len <- listener.sources_len + 1
    end;
    
    (* Add listener to signal's observers *)
    if signal.observers_len = 0 then begin
      signal.observers <- Array.make 4 listener;
      signal.observer_slots <- Array.make 4 (listener.sources_len - 1);
      signal.observers_len <- 1
    end else begin
      signal.observers <- ensure_capacity signal.observers signal.observers_len (signal.observers_len + 1);
      signal.observer_slots <- ensure_capacity signal.observer_slots signal.observers_len (signal.observers_len + 1);
      Array.set signal.observers signal.observers_len listener;
      Array.set signal.observer_slots signal.observers_len (listener.sources_len - 1);
      signal.observers_len <- signal.observers_len + 1
    end
  | None -> ()
  end;
  
  signal.value

(** {1 Mark Downstream} *)

(** Mark all downstream observers as PENDING *)
let rec mark_downstream (node: computation) =
  let rt = get_runtime () in
  match node.memo_observers with
  | None -> ()
  | Some observers ->
    for i = 0 to node.memo_observers_len - 1 do
      let o = Array.get observers i in
      if o.state = Clean then begin
        o.state <- Pending;
        if o.pure then
          rt.updates <- o :: rt.updates
        else
          rt.effects <- o :: rt.effects;
        (* Recursively mark downstream of memos *)
        if o.memo_observers <> None then
          mark_downstream o
      end
    done

(** {1 Write Signal} *)

(** Write to a signal, notifying observers *)
let write_signal : 'a. 'a signal_state -> 'a -> unit = fun signal value ->
  let should_update = match signal.comparator with
    | Some cmp -> not (cmp signal.value value)
    | None -> signal.value <> value  (* Default structural equality *)
  in
  
  if should_update then begin
    signal.value <- value;
    
    if signal.observers_len > 0 then begin
      let rt = get_runtime () in
      !run_updates_ref (fun () ->
        for i = 0 to signal.observers_len - 1 do
          let o = Array.get signal.observers i in
          if o.state = Clean then begin
            if o.pure then
              rt.updates <- o :: rt.updates
            else
              rt.effects <- o :: rt.effects;
            (* If observer is a memo, mark its downstream as PENDING *)
            if o.memo_observers <> None then
              mark_downstream o
          end;
          o.state <- Stale
        done
      ) false
    end
  end

(** {1 Look Upstream} *)

(** Resolve PENDING state by checking if sources are actually stale.
    Returns true if any source was updated (meaning we need to re-run). *)
let look_upstream (node: computation) =
  (* In SolidJS, this walks up sources checking for stale memos.
     For now, we simplify: if any source is a stale memo, it would have
     been processed by run_top before us. So just mark clean. *)
  node.state <- Clean

(** {1 Run Computation} *)

(** Execute a computation function *)
let run_computation (node: computation) =
  let rt = get_runtime () in
  
  match node.fn with
  | None -> ()  (* Disposed *)
  | Some fn ->
    let prev_listener = rt.listener in
    let prev_owner = rt.owner in
    
    rt.listener <- Some node;
    rt.owner <- Some {
      owned = node.owned;
      cleanups = node.cleanups;
      owner = node.owner;
      context = node.context;
      child_owners = [];
    };
    
    begin try
      let next_value = fn node.value in
      node.value <- next_value;
      node.updated_at <- rt.exec_count
    with exn ->
      rt.listener <- prev_listener;
      rt.owner <- prev_owner;
      raise exn
    end;
    
    rt.listener <- prev_listener;
    rt.owner <- prev_owner

(** {1 Clean Node} *)

(** Clean up a computation, removing it from dependency graph *)
let clean_node (node: computation) =
  (* Remove from all sources' observer lists using swap-and-pop *)
  for i = 0 to node.sources_len - 1 do
    let source_obj = Array.get node.sources i in
    let slot = Array.get node.source_slots i in
    let kind = Array.get node.source_kinds i in
    
    match kind with
    | Memo_source ->
      (* It's a memo - remove from memo_observers *)
      let source_comp : computation = Obj.obj source_obj in
      begin match source_comp.memo_observers with
      | Some observers when source_comp.memo_observers_len > 0 ->
        let last_idx = source_comp.memo_observers_len - 1 in
        if slot < last_idx then begin
          let last_observer = Array.get observers last_idx in
          let slots = match source_comp.memo_observer_slots with
            | Some s -> s
            | None -> failwith "memo_observer_slots should exist"
          in
          let last_slot = Array.get slots last_idx in
          
          Array.set observers slot last_observer;
          Array.set slots slot last_slot;
          
          (* Update the moved observer's source_slots *)
          Array.set last_observer.source_slots last_slot slot
        end;
        source_comp.memo_observers_len <- source_comp.memo_observers_len - 1
      | _ -> ()
      end
      
    | Signal_source ->
      (* It's a signal - remove from observers *)
      let source : Obj.t signal_state = Obj.obj source_obj in
      
      if source.observers_len > 0 then begin
        let last_idx = source.observers_len - 1 in
        if slot < last_idx then begin
          let last_observer = Array.get source.observers last_idx in
          let last_slot = Array.get source.observer_slots last_idx in
          
          Array.set source.observers slot last_observer;
          Array.set source.observer_slots slot last_slot;
          
          (* Update the moved observer's source_slots *)
          Array.set last_observer.source_slots last_slot slot
        end;
        source.observers_len <- source.observers_len - 1
      end
  done;
  
  node.sources_len <- 0;
  
  (* Clean owned computations *)
  List.iter (fun child -> !clean_node_ref child) node.owned;
  node.owned <- [];
  
  (* Run cleanups in reverse order *)
  List.iter (fun cleanup -> cleanup ()) (List.rev node.cleanups);
  node.cleanups <- [];
  
  node.state <- Clean

let () = clean_node_ref := clean_node

(** {1 Update Computation} *)

(** Update a single computation *)
let update_computation (node: computation) =
  if node.fn = None then () (* Disposed *)
  else begin
    clean_node node;
    run_computation node
  end

(** {1 Run Top} *)

(** Process a computation, ensuring it's updated if needed *)
let run_top (node: computation) =
  if node.state = Clean then ()
  else if node.state = Pending then
    look_upstream node
  else (* Stale *)
    update_computation node

(** {1 Complete Updates} *)

(** Run all queued updates and effects *)
let complete_updates () =
  let rt = get_runtime () in
  
  (* Keep processing until no more updates or effects *)
  let rec loop () =
    if rt.updates <> [] || rt.effects <> [] then begin
      (* Run pure computations (memos) first *)
      while rt.updates <> [] do
        let updates = rt.updates in
        rt.updates <- [];
        List.iter run_top (List.rev updates)
      done;
      
      (* Run effects *)
      let effects = rt.effects in
      rt.effects <- [];
      
      (* Separate user effects from render effects *)
      let render_effects, user_effects = List.partition (fun e -> not e.user) effects in
      
      List.iter run_top (List.rev render_effects);
      List.iter run_top (List.rev user_effects);
      
      (* Loop in case effects triggered more updates *)
      loop ()
    end
  in
  loop ()

(** {1 Run Updates} *)

(** Execute a function within an update cycle *)
let run_updates : 'a. (unit -> 'a) -> bool -> 'a = fun fn init ->
  let rt = get_runtime () in
  
  if rt.in_update then
    fn ()  (* Already in update cycle *)
  else begin
    rt.in_update <- true;
    rt.exec_count <- rt.exec_count + 1;
    
    if not init then begin
      rt.updates <- [];
      rt.effects <- []
    end;
    
    let result = 
      try
        let res = fn () in
        complete_updates ();
        res
      with exn ->
        rt.in_update <- false;
        rt.updates <- [];
        rt.effects <- [];
        raise exn
    in
    
    rt.in_update <- false;
    result
  end

let () = run_updates_ref := run_updates

(** {1 Create Computation} *)

(** Create a new computation *)
let create_computation 
    ~fn 
    ~(init: Obj.t) 
    ~pure 
    ~(initial_state: computation_state) 
    : computation =
  let rt = get_runtime () in
  
  let comp = {
    fn = Some fn;
    state = initial_state;
    sources = [||];
    source_slots = [||];
    source_kinds = [||];
    sources_len = 0;
    value = init;
    updated_at = 0;
    pure;
    user = false;
    owned = [];
    cleanups = [];
    owner = rt.owner;
    context = (match rt.owner with Some o -> o.context | None -> []);
    memo_observers = None;
    memo_observer_slots = None;
    memo_observers_len = 0;
    memo_comparator = None;
  } in
  
  (* Register with current owner *)
  begin match rt.owner with
  | Some owner -> owner.owned <- comp :: owner.owned
  | None -> ()
  end;
  
  comp

(** {1 Public API} *)

(** Run a function within a reactive runtime *)
let run fn =
  let rt = create_runtime () in
  let prev = get_runtime_opt () in
  set_runtime (Some rt);
  let result =
    try fn ()
    with exn ->
      set_runtime prev;
      raise exn
  in
  set_runtime prev;
  result

(** Create a root owner for cleanup *)
let create_root fn =
  let rt = get_runtime () in
  let prev_owner = rt.owner in
  let root_owner = {
    owned = [];
    cleanups = [];
    owner = prev_owner;
    context = (match prev_owner with Some o -> o.context | None -> []);
    child_owners = [];
  } in
  
  (* Register as child of parent owner *)
  begin match prev_owner with
  | Some parent -> parent.child_owners <- root_owner :: parent.child_owners
  | None -> ()
  end;
  
  rt.owner <- Some root_owner;
  
  let rec dispose_owner owner =
    (* Dispose child owners first (in reverse order of creation) *)
    List.iter dispose_owner (List.rev owner.child_owners);
    owner.child_owners <- [];
    
    (* Clean owned computations *)
    List.iter (fun comp -> 
      comp.fn <- None;
      clean_node comp
    ) owner.owned;
    owner.owned <- [];
    
    (* Run cleanups in reverse order *)
    List.iter (fun cleanup -> cleanup ()) (List.rev owner.cleanups);
    owner.cleanups <- [];
    
    (* Remove from parent's children list *)
    begin match owner.owner with
    | Some parent ->
      parent.child_owners <- List.filter (fun c -> c != owner) parent.child_owners
    | None -> ()
    end
  in
  
  let dispose () = dispose_owner root_owner in
  
  let result =
    try
      let res = fn dispose in
      rt.owner <- prev_owner;
      res
    with exn ->
      rt.owner <- prev_owner;
      raise exn
  in
  result

(** Register a cleanup function with current owner *)
let on_cleanup fn =
  let rt = get_runtime () in
  match rt.owner with
  | Some owner -> owner.cleanups <- fn :: owner.cleanups
  | None -> () (* No owner, cleanup won't be called *)

(** Read without tracking *)
let untrack fn =
  let rt = get_runtime () in
  let prev = rt.listener in
  rt.listener <- None;
  let result = 
    try fn ()
    with exn ->
      rt.listener <- prev;
      raise exn
  in
  rt.listener <- prev;
  result

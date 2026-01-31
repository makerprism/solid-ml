(** Functor-based reactive core.
    
    This module contains all the reactive algorithms that are shared
    between server and browser implementations. The only difference
    is how the current runtime is stored, which is abstracted via
    the Backend module.
*)

open Types

(** Create a reactive system with the given backend *)
module Make (B : Backend.S) = struct
  (** {1 Runtime State} *)
  
  let get_runtime () =
    match B.get_runtime () with
    | Some rt -> rt
    | None ->
      if B.allow_implicit_runtime then
        let rt = create_runtime () in
        B.set_runtime (Some rt);
        rt
      else
        raise
          (No_runtime
             "solid-ml: No runtime active. Wrap in Runtime.run or use SSR helpers (Render.to_string/to_document).")
  
  let get_runtime_opt () = B.get_runtime ()
  
  let set_runtime rt = B.set_runtime rt

  let with_owner (owner_opt : owner option) (fn : unit -> 'a) : 'a =
    match get_runtime_opt () with
    | None -> fn ()
    | Some rt ->
      let prev_owner = rt.owner in
      rt.owner <- owner_opt;
      match fn () with
      | value ->
        rt.owner <- prev_owner;
        value
      | exception exn ->
        rt.owner <- prev_owner;
        raise exn
  
  (** {1 Array Helpers} *)
  
  let ensure_capacity (type a) (arr : a array) (len : int) (needed : int) (default : a) : a array =
    let current_len = Array.length arr in
    if current_len >= needed then arr
    else begin
      let new_len = max needed (current_len * 2) in
      let new_arr = Array.make new_len default in
      Array.blit arr 0 new_arr 0 len;
      new_arr
    end

  let ensure_capacity_kinds arr len needed =
    let current_len = Array.length arr in
    if current_len >= needed then arr
    else begin
      let new_len = max needed (current_len * 2) in
      let new_arr = Array.make new_len Signal_source in
      Array.blit arr 0 new_arr 0 len;
      new_arr
    end

  (** {1 List Helpers} *)
  
  (** Iterate a list in reverse order without allocating a reversed copy *)
  let iter_rev f = function
    | [] -> ()
    | [x] -> f x
    | [x; y] -> f y; f x
    | [x; y; z] -> f z; f y; f x
    | lst ->
      (* For longer lists, we need to reverse - but this is rare in practice *)
      List.iter f (List.rev lst)

  (** {1 Queue Helpers} *)
  
  (** Push a computation onto the updates queue - optimized *)
  let push_update_immediate rt comp =
    let len = rt.updates_len in
    let arr = rt.updates in
    if len >= Array.length arr then begin
      (* Optimized: use same growth factor as arrays *)
      let growth_factor = if len < 64 then 2.0 else 1.5 in
      let new_len = int_of_float (float_of_int len *. growth_factor) in
      let new_arr = Array.make new_len dummy_computation in
      Array.blit arr 0 new_arr 0 len;
      rt.updates <- new_arr
    end;
    Array.unsafe_set rt.updates len comp;
    rt.updates_len <- len + 1

  (** Push a computation onto the transition updates queue - optimized *)
  let push_update_transition rt comp =
    let len = rt.transition_updates_len in
    let arr = rt.transition_updates in
    if len >= Array.length arr then begin
      let growth_factor = if len < 64 then 2.0 else 1.5 in
      let new_len = int_of_float (float_of_int len *. growth_factor) in
      let new_arr = Array.make new_len dummy_computation in
      Array.blit arr 0 new_arr 0 len;
      rt.transition_updates <- new_arr
    end;
    Array.unsafe_set rt.transition_updates len comp;
    rt.transition_updates_len <- len + 1
  
  (** Push a computation onto the effects queue - optimized *)
  let push_effect_immediate rt comp =
    let len = rt.effects_len in
    let arr = rt.effects in
    if len >= Array.length arr then begin
      (* Optimized: use same growth factor as arrays *)
      let growth_factor = if len < 64 then 2.0 else 1.5 in
      let new_len = int_of_float (float_of_int len *. growth_factor) in
      let new_arr = Array.make new_len dummy_computation in
      Array.blit arr 0 new_arr 0 len;
      rt.effects <- new_arr
    end;
    Array.unsafe_set rt.effects len comp;
    rt.effects_len <- len + 1

  (** Push a computation onto the transition effects queue - optimized *)
  let push_effect_transition rt comp =
    let len = rt.transition_effects_len in
    let arr = rt.transition_effects in
    if len >= Array.length arr then begin
      let growth_factor = if len < 64 then 2.0 else 1.5 in
      let new_len = int_of_float (float_of_int len *. growth_factor) in
      let new_arr = Array.make new_len dummy_computation in
      Array.blit arr 0 new_arr 0 len;
      rt.transition_effects <- new_arr
    end;
    Array.unsafe_set rt.transition_effects len comp;
    rt.transition_effects_len <- len + 1

  let transition_enqueue rt = rt.transition_depth > 0 || rt.transition_processing

  let set_transition_pending_ref : (runtime -> bool -> unit) ref = ref (fun _ _ -> ())
  let process_transition_queue_ref : (runtime -> unit) ref = ref (fun _ -> ())
  let schedule_transition_ref : (runtime -> unit) ref = ref (fun _ -> ())

  let push_update rt comp =
    if transition_enqueue rt then (
      push_update_transition rt comp;
      !schedule_transition_ref rt)
    else
      push_update_immediate rt comp

  let push_effect rt comp =
    if transition_enqueue rt then (
      push_effect_transition rt comp;
      !schedule_transition_ref rt)
    else
      push_effect_immediate rt comp

  (** {1 Forward Declarations} *)
  
  let clean_node_ref : (computation -> unit) ref = ref (fun _ -> ())
  let dispose_owner_ref : (owner -> unit) ref = ref (fun _ -> ())
  
  (** {1 Dependency Tracking} *)
  
  (** Read a signal, tracking the dependency if there's a listener *)
  let read_signal (signal : signal_state) : Obj.t =
    let rt = get_runtime () in
    
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
        listener.sources <- ensure_capacity listener.sources listener.sources_len 
          (listener.sources_len + 1) (Obj.repr signal);
        listener.source_slots <- ensure_capacity listener.source_slots listener.sources_len 
          (listener.sources_len + 1) 0;
        listener.source_kinds <- ensure_capacity_kinds listener.source_kinds listener.sources_len 
          (listener.sources_len + 1);
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
        signal.observers <- ensure_capacity signal.observers signal.observers_len 
          (signal.observers_len + 1) dummy_computation;
        signal.observer_slots <- ensure_capacity signal.observer_slots signal.observers_len 
          (signal.observers_len + 1) 0;
        Array.set signal.observers signal.observers_len listener;
        Array.set signal.observer_slots signal.observers_len (listener.sources_len - 1);
        signal.observers_len <- signal.observers_len + 1
      end
    | None -> ()
    end;
    
    signal.sig_value
  
  (** Read a memo, tracking the dependency if there's a listener *)
  let read_memo (memo : computation) : Obj.t =
    let rt = get_runtime () in
    
    begin match rt.listener with
    | Some listener when memo.memo_observers <> None ->
      let m_slot = memo.memo_observers_len in
      
      (* Add memo to listener's sources *)
      if listener.sources_len = 0 then begin
        listener.sources <- Array.make 4 (Obj.repr memo);
        listener.source_slots <- Array.make 4 m_slot;
        listener.source_kinds <- Array.make 4 Memo_source;
        listener.sources_len <- 1
      end else begin
        listener.sources <- ensure_capacity listener.sources listener.sources_len 
          (listener.sources_len + 1) (Obj.repr memo);
        listener.source_slots <- ensure_capacity listener.source_slots listener.sources_len 
          (listener.sources_len + 1) 0;
        listener.source_kinds <- ensure_capacity_kinds listener.source_kinds listener.sources_len 
          (listener.sources_len + 1);
        Array.set listener.sources listener.sources_len (Obj.repr memo);
        Array.set listener.source_slots listener.sources_len m_slot;
        Array.set listener.source_kinds listener.sources_len Memo_source;
        listener.sources_len <- listener.sources_len + 1
      end;
      
      (* Add listener to memo's observers *)
      let observers = match memo.memo_observers with Some o -> o | None -> [||] in
      let slots = match memo.memo_observer_slots with Some s -> s | None -> [||] in
      
      if memo.memo_observers_len = 0 then begin
        memo.memo_observers <- Some (Array.make 4 listener);
        memo.memo_observer_slots <- Some (Array.make 4 (listener.sources_len - 1));
        memo.memo_observers_len <- 1
      end else begin
        let new_observers = ensure_capacity observers memo.memo_observers_len 
          (memo.memo_observers_len + 1) dummy_computation in
        let new_slots = ensure_capacity slots memo.memo_observers_len 
          (memo.memo_observers_len + 1) 0 in
        Array.set new_observers memo.memo_observers_len listener;
        Array.set new_slots memo.memo_observers_len (listener.sources_len - 1);
        memo.memo_observers <- Some new_observers;
        memo.memo_observer_slots <- Some new_slots;
        memo.memo_observers_len <- memo.memo_observers_len + 1
      end
    | _ -> ()
    end;
    
    memo.value

  (** {1 Mark Downstream} *)
  
  (** Mark all downstream observers as needing update *)
  let rec mark_downstream (node : computation) =
    let rt = get_runtime () in
    match node.memo_observers with
    | None -> ()
    | Some observers ->
      let enqueue_observer (o : computation) =
        if o.transition then
          if o.pure then
            push_update_transition rt o
          else
            push_effect_transition rt o
        else if o.pure then
          push_update rt o
        else
          push_effect rt o
      in
      for i = 0 to node.memo_observers_len - 1 do
        let o = Array.get observers i in
        if o.state = Clean then begin
          o.state <- Pending;
          enqueue_observer o;
          if o.memo_observers <> None then
            mark_downstream o
        end
      done

  (** {1 Write Signal} *)
  
  (** Forward declaration for run_updates *)
  let run_updates_ref : ((unit -> 'a) -> bool -> 'a) ref = ref (fun f _ -> f ())
  
  (** Write to a signal, notifying observers *)
  let write_signal (signal : signal_state) (value : Obj.t) : unit =
    (* Default: use physical inequality (==) like SolidJS's === *)
    let should_update = match signal.comparator with
      | Some cmp -> not (cmp signal.sig_value value)
      | None -> signal.sig_value != value  (* Physical inequality, matching SolidJS *)
    in
    
    if should_update then begin
      signal.sig_value <- value;
      
      if signal.observers_len > 0 then begin
        let rt = get_runtime () in
        !run_updates_ref (fun () ->
          (* Cache array accesses for performance *)
          let observers = signal.observers in
          let observers_len = signal.observers_len in
          let enqueue_observer (o : computation) =
            if o.transition then
              if o.pure then
                push_update_transition rt o
              else
                push_effect_transition rt o
            else if o.pure then
              push_update rt o
            else
              push_effect rt o
          in
          
          for i = 0 to observers_len - 1 do
            let o = Array.unsafe_get observers i in
            if o.state = Clean then begin
              enqueue_observer o;
              if o.memo_observers <> None then
                mark_downstream o
              end;
            o.state <- Stale
          done
        ) false
      end
    end

  let set_transition_pending rt value =
    let current = Obj.obj rt.transition_pending.sig_value in
    if current <> value then
      write_signal rt.transition_pending (Obj.repr value)

  let () = set_transition_pending_ref := set_transition_pending

  let schedule_transition rt =
    if not rt.transition_scheduled then begin
      rt.transition_scheduled <- true;
      set_transition_pending rt true;
      B.schedule_transition (fun () ->
          match get_runtime_opt () with
          | None -> ()
          | Some runtime ->
            if runtime.in_update then
              ()
            else
              !process_transition_queue_ref runtime)
    end

  let () = schedule_transition_ref := schedule_transition


  (** {1 Clean Node} *)
  
  (** Clean up a computation, removing it from dependency graph *)
  let clean_node (node : computation) =
    for i = 0 to node.sources_len - 1 do
      let source_obj = Array.get node.sources i in
      let slot = Array.get node.source_slots i in
      let kind = Array.get node.source_kinds i in
      
      match kind with
      | Memo_source ->
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
            Array.set last_observer.source_slots last_slot slot
          end;
          source_comp.memo_observers_len <- source_comp.memo_observers_len - 1
        | _ -> ()
        end
        
      | Signal_source ->
        let source : signal_state = Obj.obj source_obj in
        if source.observers_len > 0 then begin
          let last_idx = source.observers_len - 1 in
          if slot < last_idx then begin
            let last_observer = Array.get source.observers last_idx in
            let last_slot = Array.get source.observer_slots last_idx in
            Array.set source.observers slot last_observer;
            Array.set source.observer_slots slot last_slot;
            Array.set last_observer.source_slots last_slot slot
          end;
          source.observers_len <- source.observers_len - 1
        end
    done;
    
    node.sources_len <- 0;
    
    (* Dispose child owners (roots created inside this computation) - newest first *)
    iter_rev (fun child_owner -> !dispose_owner_ref child_owner) node.child_owners;
    node.child_owners <- [];
    
    (* Clean owned computations *)
    List.iter (fun child -> !clean_node_ref child) node.owned;
    node.owned <- [];
    
    (* Run cleanups in reverse order (newest first) *)
    iter_rev (fun cleanup -> cleanup ()) node.cleanups;
    node.cleanups <- [];
    
    node.state <- Clean

  let () = clean_node_ref := clean_node

  (** {1 Run Computation} *)
  
  (** Execute a computation function *)
  let run_computation (node : computation) =
    let rt = get_runtime () in
    
    match node.fn with
    | None -> ()
    | Some fn ->
      let prev_listener = rt.listener in
      let prev_owner = rt.owner in
      
      (* Create a temporary owner to collect nested computations/cleanups/child_owners.
         After execution, we copy these back to the node. *)
      let temp_owner = {
        o_owned = [];  (* Will collect new nested computations *)
        o_cleanups = [];  (* Will collect new cleanups *)
        o_parent = node.owner;
        o_context = node.context;
        o_child_owners = [];  (* Will collect new roots created inside *)
      } in
      
      rt.listener <- Some node;
      rt.owner <- Some temp_owner;
      
      begin try
        let next_value = fn node.value in
        node.value <- next_value;
        node.updated_at <- rt.exec_count;
        (* Copy registered computations, cleanups, and child owners back to node *)
        node.owned <- temp_owner.o_owned;
        node.cleanups <- temp_owner.o_cleanups;
        node.child_owners <- temp_owner.o_child_owners
      with exn ->
        (* Still copy on exception so cleanup can run *)
        node.owned <- temp_owner.o_owned;
        node.cleanups <- temp_owner.o_cleanups;
        node.child_owners <- temp_owner.o_child_owners;
        rt.listener <- prev_listener;
        rt.owner <- prev_owner;
        raise exn
      end;
      
      rt.listener <- prev_listener;
      rt.owner <- prev_owner

  (** {1 Update Computation} *)
  
  let update_computation (node : computation) =
    if node.fn = None then ()
    else begin
      clean_node node;
      run_computation node
    end

  (** {1 Run Top} *)
  
  (** Resolve PENDING state.
      
      A node is PENDING when an upstream memo was queued for update but
      we don't know if its value actually changed. Since we process memos
      in topological order (pure computations first), by the time we reach
      a PENDING node, all its upstream memos have already run.
      
      If an upstream memo's value changed, it would have marked this node
      as STALE. So if we're still PENDING, no upstream values changed and
      we can safely mark this node CLEAN without recomputing. *)
  let look_upstream (node : computation) =
    node.state <- Clean

  let run_top (node : computation) =
    if node.state = Clean then ()
    else if node.state = Pending then
      look_upstream node
    else
      update_computation node

  (** {1 Complete Updates} *)
  
  let complete_updates () =
    let rt = get_runtime () in

    let run_with_error_handler node context =
      let prev_handler = rt.current_error_handler in
      rt.current_error_handler <- node.error_handler;
      match (try run_top node with exn -> B.handle_error exn context) with
      | value ->
        rt.current_error_handler <- prev_handler;
        value
      | exception exn ->
        rt.current_error_handler <- prev_handler;
        raise exn
    in

    let rec loop () =
      if rt.updates_len > 0 || rt.effects_len > 0 then begin
        (* Process updates (memos) - already in correct order *)
        while rt.updates_len > 0 do
          let len = rt.updates_len in
          let updates = rt.updates in
          rt.updates_len <- 0;
          for i = 0 to len - 1 do
            let node = Array.unsafe_get updates i in
            run_with_error_handler node "memo"
          done
        done;
        
        (* Process effects - render effects first, then user effects *)
        let effects_len = rt.effects_len in
        let effects = rt.effects in
        rt.effects_len <- 0;
        
        (* First pass: render effects (not user) *)
        for i = 0 to effects_len - 1 do
          let node = Array.unsafe_get effects i in
          if not node.user then
            run_with_error_handler node "effect"
        done;

        (* Second pass: user effects *)
        for i = 0 to effects_len - 1 do
          let node = Array.unsafe_get effects i in
          if node.user then
            run_with_error_handler node "effect"
        done;
        
        loop ()
      end
    in
    loop ()

  (** {1 Run Updates} *)
  
  let rec schedule_deferred_updates rt =
    if not rt.updates_scheduled then begin
      rt.updates_scheduled <- true;
      B.schedule_microtask (fun () ->
          match get_runtime_opt () with
          | None ->
            rt.updates_scheduled <- false
          | Some runtime ->
            if runtime.in_update then begin
              runtime.updates_scheduled <- false;
              schedule_deferred_updates runtime
            end else begin
              runtime.updates_scheduled <- false;
              runtime.in_update <- true;
              runtime.exec_count <- runtime.exec_count + 1;
              (try
                 complete_updates ()
               with exn ->
                 runtime.in_update <- false;
                 raise exn);
              runtime.in_update <- false;
              if runtime.transition_scheduled then
                !process_transition_queue_ref runtime
            end)
    end

  let run_updates : 'a. (unit -> 'a) -> bool -> 'a = fun fn init ->
    let rt = get_runtime () in
    
    if rt.in_update then
      fn ()
    else if rt.defer_updates && not init then begin
      let had_scheduled = rt.updates_scheduled in
      rt.in_update <- true;

      if not had_scheduled then begin
        rt.updates_len <- 0;
        rt.effects_len <- 0
      end;

      let result =
        try fn ()
        with exn ->
          rt.in_update <- false;
          if not had_scheduled then begin
            rt.updates_len <- 0;
            rt.effects_len <- 0
          end;
          raise exn
      in

      rt.in_update <- false;
      schedule_deferred_updates rt;
      result
    end else begin
      rt.in_update <- true;
      rt.exec_count <- rt.exec_count + 1;
      
      if not init then begin
        rt.updates_len <- 0;
        rt.effects_len <- 0
      end;
      
      let result = 
        try
          let res = fn () in
          complete_updates ();
          res
        with exn ->
          rt.in_update <- false;
          rt.updates_len <- 0;
          rt.effects_len <- 0;
          raise exn
      in
      
      rt.in_update <- false;
      if rt.transition_scheduled then
        !process_transition_queue_ref rt;
      result
    end

  let () = run_updates_ref := run_updates

  let process_transition_queue rt =
    if rt.in_update then
      ()
    else if rt.transition_updates_len = 0 && rt.transition_effects_len = 0 then (
      rt.transition_scheduled <- false;
      set_transition_pending rt false)
    else begin
      rt.transition_processing <- true;
      rt.transition_scheduled <- false;

      let normal_updates = rt.updates in
      let normal_updates_len = rt.updates_len in
      let normal_effects = rt.effects in
      let normal_effects_len = rt.effects_len in

      rt.updates <- rt.transition_updates;
      rt.effects <- rt.transition_effects;
      rt.updates_len <- rt.transition_updates_len;
      rt.effects_len <- rt.transition_effects_len;
      rt.transition_updates_len <- 0;
      rt.transition_effects_len <- 0;

      complete_updates ();

      rt.updates <- normal_updates;
      rt.effects <- normal_effects;
      rt.updates_len <- normal_updates_len;
      rt.effects_len <- normal_effects_len;

      rt.transition_processing <- false;
      if rt.transition_updates_len > 0 || rt.transition_effects_len > 0 then
        schedule_transition rt
      else
        set_transition_pending rt false
    end

  let () = process_transition_queue_ref := process_transition_queue

  let run_transition fn =
    let rt = get_runtime () in
    rt.transition_depth <- rt.transition_depth + 1;
    match run_updates (fun () -> fn ()) false with
    | value ->
      rt.transition_depth <- rt.transition_depth - 1;
      value
    | exception exn ->
      rt.transition_depth <- rt.transition_depth - 1;
      raise exn

  let transition_pending_signal () =
    let rt = get_runtime () in
    rt.transition_pending

  (** {1 Create Computation} *)
  
  let create_computation ~fn ~(init: Obj.t) ~pure ~(initial_state: computation_state) : computation =
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
      error_handler = rt.current_error_handler;
      owned = [];
      cleanups = [];
      owner = rt.owner;
      context = (match rt.owner with Some o -> o.o_context | None -> []);
      child_owners = [];
      memo_observers = None;
      memo_observer_slots = None;
      memo_observers_len = 0;
      memo_comparator = None;
      transition = rt.transition_depth > 0;
    } in
    
    begin match rt.owner with
    | Some owner -> owner.o_owned <- comp :: owner.o_owned
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

  (** Enable or disable microtask-deferring updates. *)
  let set_microtask_deferral enabled =
    let rt = get_runtime () in
    rt.defer_updates <- enabled

  (** Dispose an owner and all its children *)
  let rec dispose_owner (owner : owner) =
    (* Dispose child owners first (depth-first, newest first) *)
    iter_rev dispose_owner owner.o_child_owners;
    owner.o_child_owners <- [];
    
    (* Clean owned computations *)
    List.iter (fun comp -> 
      comp.fn <- None;
      clean_node comp
    ) owner.o_owned;
    owner.o_owned <- [];
    
    (* Run cleanups in reverse order (newest first) *)
    iter_rev (fun cleanup -> cleanup ()) owner.o_cleanups;
    owner.o_cleanups <- [];
    
    (* Remove self from parent's child_owners *)
    begin match owner.o_parent with
    | Some parent ->
      parent.o_child_owners <- List.filter (fun c -> c != owner) parent.o_child_owners
    | None -> ()
    end
  
  let () = dispose_owner_ref := dispose_owner

  (** Create a root owner for cleanup *)
  let create_root fn =
    let rt = get_runtime () in
    let prev_owner = rt.owner in
    let root_owner = {
      o_owned = [];
      o_cleanups = [];
      o_parent = prev_owner;
      o_context = (match prev_owner with Some o -> o.o_context | None -> []);
      o_child_owners = [];
    } in
    
    begin match prev_owner with
    | Some parent -> parent.o_child_owners <- root_owner :: parent.o_child_owners
    | None -> ()
    end;
    
    rt.owner <- Some root_owner;
    
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

  (** Register a cleanup function *)
  let on_cleanup fn =
    let rt = get_runtime () in
    match rt.owner with
    | Some owner -> owner.o_cleanups <- fn :: owner.o_cleanups
    | None -> ()

  (** Get current owner *)
  let get_owner () =
    let rt = get_runtime () in
    rt.owner

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

  (** {1 Low-level Signal API (Obj.t)} *)
  
  let create_signal_internal ?comparator initial =
    {
      sig_value = initial;
      observers = [||];
      observer_slots = [||];
      observers_len = 0;
      comparator;
    }

  (** {1 Typed Signal API} *)
  
  (** Create a typed signal with optional equality function *)
  let create_typed_signal (type a) ?(equals : (a -> a -> bool) option) (initial : a) : a signal =
    ignore (get_runtime ());
    let comparator = match equals with
      | Some eq -> Some (fun a b -> eq (Obj.obj a) (Obj.obj b))
      | None -> None
    in
    create_signal_internal ?comparator (Obj.repr initial)
  
  (** Read a typed signal with tracking *)
  let read_typed_signal (type a) (s : a signal) : a =
    Obj.obj (read_signal s)
  
  (** Write to a typed signal *)
  let write_typed_signal (type a) (s : a signal) (v : a) : unit =
    write_signal s (Obj.repr v)
  
  (** Peek at signal value without tracking *)
  let peek_typed_signal (type a) (s : a signal) : a =
    Obj.obj s.sig_value

  (** {1 Typed Memo API} *)
  
  (** Create a typed memo *)
  let create_typed_memo (type a) ?(equals : (a -> a -> bool) = (=)) (fn : unit -> a) : a memo =
    let memo_ref : a memo option ref = ref None in
    
    let comp = create_computation
      ~fn:(fun _prev ->
        let new_val = fn () in
        begin match !memo_ref with
        | Some m ->
          if m.has_cached && not (m.equals m.cached new_val) then begin
            (* Value changed - mark downstream *)
            m.cached <- new_val;
            let rt = get_runtime () in
            begin match m.comp.memo_observers with
            | Some observers ->
              for i = 0 to m.comp.memo_observers_len - 1 do
                let o = Array.get observers i in
                if o.state = Clean then begin
                  o.state <- Stale;
                  if o.pure then push_update rt o
                  else push_effect rt o
                end else if o.state = Pending then
                  o.state <- Stale
              done
            | None -> ()
            end
          end else begin
            m.cached <- new_val;
            m.has_cached <- true
          end
        | None -> ()
        end;
        Obj.repr new_val
      )
      ~init:(Obj.repr ())
      ~pure:true
      ~initial_state:Stale
    in
    
    comp.memo_observers <- Some [||];
    comp.memo_observer_slots <- Some [||];
    
    let m : a memo = {
      comp;
      cached = Obj.magic ();
      has_cached = false;
      equals;
    } in
    memo_ref := Some m;
    
    (* Eager evaluation *)
    update_computation comp;
    m
  
  (** Read a typed memo with tracking *)
  let read_typed_memo (type a) (m : a memo) : a =
    let comp = m.comp in
    
    (* Recompute if stale *)
    if comp.state = Stale then begin
      clean_node comp;
      run_computation comp;
      comp.state <- Clean
    end else if comp.state = Pending then begin
      look_upstream comp;
      if comp.state = Stale then begin
        clean_node comp;
        run_computation comp;
        comp.state <- Clean
      end
    end;
    
    (* Track dependency *)
    let rt = get_runtime () in
    begin match rt.listener with
    | Some listener ->
      let s_slot = comp.memo_observers_len in
      
      (* Add memo to listener's sources *)
      if listener.sources_len = 0 then begin
        listener.sources <- Array.make 4 (Obj.repr comp);
        listener.source_slots <- Array.make 4 s_slot;
        listener.source_kinds <- Array.make 4 Memo_source;
        listener.sources_len <- 1
      end else begin
        listener.sources <- ensure_capacity listener.sources listener.sources_len 
          (listener.sources_len + 1) (Obj.repr comp);
        listener.source_slots <- ensure_capacity listener.source_slots listener.sources_len 
          (listener.sources_len + 1) 0;
        listener.source_kinds <- ensure_capacity_kinds listener.source_kinds listener.sources_len 
          (listener.sources_len + 1);
        Array.set listener.sources listener.sources_len (Obj.repr comp);
        Array.set listener.source_slots listener.sources_len s_slot;
        Array.set listener.source_kinds listener.sources_len Memo_source;
        listener.sources_len <- listener.sources_len + 1
      end;
      
      (* Add listener to memo's observers *)
      let observers = match comp.memo_observers with Some o -> o | None -> [||] in
      let slots = match comp.memo_observer_slots with Some s -> s | None -> [||] in
      
      if comp.memo_observers_len = 0 then begin
        comp.memo_observers <- Some (Array.make 4 listener);
        comp.memo_observer_slots <- Some (Array.make 4 (listener.sources_len - 1));
        comp.memo_observers_len <- 1
      end else begin
        let new_observers = ensure_capacity observers comp.memo_observers_len 
          (comp.memo_observers_len + 1) dummy_computation in
        let new_slots = ensure_capacity slots comp.memo_observers_len 
          (comp.memo_observers_len + 1) 0 in
        Array.set new_observers comp.memo_observers_len listener;
        Array.set new_slots comp.memo_observers_len (listener.sources_len - 1);
        comp.memo_observers <- Some new_observers;
        comp.memo_observer_slots <- Some new_slots;
        comp.memo_observers_len <- comp.memo_observers_len + 1
      end
    | None -> ()
    end;
    
    m.cached
  
  (** Peek at memo value without tracking *)
  let peek_typed_memo (type a) (m : a memo) : a = m.cached

  (** {1 Effect API} *)
  
  (** Create an effect that runs when dependencies change.
      The effect function is called immediately, and then re-called
      whenever any signal read during execution changes. *)
  let create_effect (fn : unit -> unit) : unit =
    let comp = create_computation
      ~fn:(fun _ -> fn (); Obj.repr ())
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Stale
    in
    comp.user <- true;
    
    let rt = get_runtime () in
    if rt.in_update then
      push_effect rt comp
    else
      run_updates (fun () -> run_top comp) true

  (** Create a render effect (like SolidJS's createRenderEffect/createComputed).
      Render effects run before user effects during update flush. *)
  let create_render_effect (fn : unit -> unit) : unit =
    let comp = create_computation
      ~fn:(fun _ -> fn (); Obj.repr ())
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Stale
    in
    let rt = get_runtime () in
    if rt.in_update then
      run_top comp
    else
      run_updates (fun () -> run_top comp) true

  (** Create a render effect with a cleanup function. *)
  let create_render_effect_with_cleanup (fn : unit -> (unit -> unit)) : unit =
    let cleanup_ref = ref (fun () -> ()) in
    let comp = create_computation
      ~fn:(fun _ ->
        !cleanup_ref ();
        let new_cleanup = fn () in
        cleanup_ref := new_cleanup;
        Obj.repr ()
      )
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Stale
    in
    on_cleanup (fun () -> !cleanup_ref ());
    let rt = get_runtime () in
    if rt.in_update then
      run_top comp
    else
      run_updates (fun () -> run_top comp) true

  let create_computed = create_render_effect
  let create_computed_with_cleanup = create_render_effect_with_cleanup
  
  (** Create an effect with a cleanup function.
      The effect function should return a cleanup function that will
      be called before the next execution and when the effect is disposed. *)
  let create_effect_with_cleanup (fn : unit -> (unit -> unit)) : unit =
    let cleanup_ref = ref (fun () -> ()) in
    
    let comp = create_computation
      ~fn:(fun _ ->
        !cleanup_ref ();
        let new_cleanup = fn () in
        cleanup_ref := new_cleanup;
        Obj.repr ()
      )
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Stale
    in
    comp.user <- true;
    
    on_cleanup (fun () -> !cleanup_ref ());
    
    let rt = get_runtime () in
    if rt.in_update then
      push_effect rt comp
    else
      run_updates (fun () -> run_top comp) true

  (** Create an effect that skips the side effect on first execution.
      Useful when initial values are set directly and only updates need the effect.
      This avoids the pattern of using a mutable ref to skip the first run.
      
      The effect function is split into two parts:
      - [track]: Called on every execution to read signals and establish dependencies
      - [run]: Called only after the first execution to perform the side effect
      
      Example:
      {[
        (* Initial value set directly *)
        Dom.set_text_content el (Signal.peek label);
        (* Effect only updates on changes *)
        Effect.create_deferred
          ~track:(fun () -> Signal.get label)
          ~run:(fun label -> Dom.set_text_content el label)
      ]} *)
  let create_effect_deferred ~(track : unit -> 'a) ~(run : 'a -> unit) : unit =
    let first_run = ref true in
    let comp = create_computation
      ~fn:(fun _ ->
        let value = track () in
        if !first_run then
          first_run := false
        else
          run value;
        Obj.repr ()
      )
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Stale
    in
    comp.user <- true;
    
    let rt = get_runtime () in
    if rt.in_update then
      push_effect rt comp
    else
      run_updates (fun () -> run_top comp) true

  (** Create a reaction that tracks dependencies explicitly.
      Returns a function that establishes dependencies when called. *)
  let create_reaction (type a) (fn : value:a -> prev:a -> unit) : (unit -> a) -> unit =
    let tracking = ref None in
    let prev = ref None in
    let first_run = ref true in
    let comp = create_computation
      ~fn:(fun _ ->
        match !tracking with
        | None -> Obj.repr ()
        | Some track_fn ->
          let value = track_fn () in
          if !first_run then begin
            first_run := false;
            prev := Some value;
            Obj.repr ()
          end else begin
            let prev_val = match !prev with
              | Some p -> p
              | None -> value
            in
            untrack (fun () -> fn ~value ~prev:prev_val);
            prev := Some value;
            Obj.repr ()
          end
      )
      ~init:(Obj.repr ())
      ~pure:false
      ~initial_state:Clean
    in
    fun track_fn ->
      tracking := Some track_fn;
      first_run := true;
      prev := None;
      comp.state <- Stale;
      let rt = get_runtime () in
      if rt.in_update then
        push_effect rt comp
      else
        run_updates (fun () -> run_top comp) true

  (** {1 Context API} *)
  
  (** A context holds a default value and a unique ID *)
  type 'a context = {
    ctx_id: int;
    ctx_default: 'a;
  }
  
  (** Counter for unique context IDs.
      
      Note: This uses a regular ref, not Atomic.t, because:
      1. Browser (Melange) doesn't have Atomic
      2. Contexts are typically created at module initialization time
         (before any concurrent execution)
      3. In practice, concurrent context creation is rare
      
      If thread-safe context creation is needed on server, create all
      contexts before spawning domains. *)
  let next_context_id = ref 0
  
  (** Create a new context with a default value.
      
      Note: Context creation is not thread-safe. Create contexts at
      module initialization time, before spawning domains. *)
  let create_context (type a) (default : a) : a context =
    let id = !next_context_id in
    incr next_context_id;
    { ctx_id = id; ctx_default = default }
  
  (** Find a context value by walking up the owner tree *)
  let rec find_context_in_owner ctx_id (owner : owner) : Obj.t option =
    match List.assoc_opt ctx_id owner.o_context with
    | Some v -> Some v
    | None ->
      match owner.o_parent with
      | Some parent -> find_context_in_owner ctx_id parent
      | None -> None
  
  (** Use (read) a context value.
      Looks up the owner tree for a provided value.
      Returns the default if no value was provided. *)
  let use_context (type a) (ctx : a context) : a =
    match get_runtime_opt () with
    | Some rt ->
      (match rt.owner with
       | Some owner ->
         (match find_context_in_owner ctx.ctx_id owner with
          | Some v -> Obj.obj v
          | None -> ctx.ctx_default)
       | None -> ctx.ctx_default)
    | None -> ctx.ctx_default
  
  (** Provide a context value for a scope.
      All [use_context] calls within [fn] (and its descendants) will
      see the provided value instead of the default. *)
  let provide_context (type a) (ctx : a context) (value : a) (fn : unit -> 'b) : 'b =
    match get_runtime_opt () with
    | Some rt ->
      (match rt.owner with
       | Some owner ->
         let prev = owner.o_context in
         owner.o_context <- (ctx.ctx_id, Obj.repr value) :: prev;
         let result =
           try fn ()
           with e ->
             owner.o_context <- prev;
             raise e
         in
         owner.o_context <- prev;
         result
       | None ->
         (* No owner - create a root to hold the context *)
         create_root (fun _dispose ->
           let rt = get_runtime () in
           match rt.owner with
           | Some owner ->
             owner.o_context <- (ctx.ctx_id, Obj.repr value) :: owner.o_context;
             fn ()
           | None -> fn ()
         ))
    | None ->
      (* No runtime - create one with a root *)
      run (fun () ->
        create_root (fun _dispose ->
          let rt = get_runtime () in
          match rt.owner with
          | Some owner ->
            owner.o_context <- (ctx.ctx_id, Obj.repr value) :: owner.o_context;
            fn ()
          | None -> fn ()
        ))
end

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
    | None -> failwith "No reactive runtime active. Use Runtime.run or create_root."
  
  let get_runtime_opt () = B.get_runtime ()
  
  let set_runtime rt = B.set_runtime rt
  
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

  (** {1 Forward Declarations} *)
  
  let clean_node_ref : (computation -> unit) ref = ref (fun _ -> ())
  
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
          (signal.observers_len + 1) (empty_computation ());
        signal.observer_slots <- ensure_capacity signal.observer_slots signal.observers_len 
          (signal.observers_len + 1) 0;
        Array.set signal.observers signal.observers_len listener;
        Array.set signal.observer_slots signal.observers_len (listener.sources_len - 1);
        signal.observers_len <- signal.observers_len + 1
      end
    | None -> ()
    end;
    
    signal.value
  
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
          (memo.memo_observers_len + 1) (empty_computation ()) in
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
      for i = 0 to node.memo_observers_len - 1 do
        let o = Array.get observers i in
        if o.state = Clean then begin
          o.state <- Pending;
          if o.pure then
            rt.updates <- o :: rt.updates
          else
            rt.effects <- o :: rt.effects;
          if o.memo_observers <> None then
            mark_downstream o
        end
      done

  (** {1 Write Signal} *)
  
  (** Forward declaration for run_updates *)
  let run_updates_ref : ((unit -> 'a) -> bool -> 'a) ref = ref (fun f _ -> f ())
  
  (** Write to a signal, notifying observers *)
  let write_signal (signal : signal_state) (value : Obj.t) : unit =
    let should_update = match signal.comparator with
      | Some cmp -> not (cmp signal.value value)
      | None -> signal.value <> value
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
              if o.memo_observers <> None then
                mark_downstream o
            end;
            o.state <- Stale
          done
        ) false
      end
    end

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
    
    (* Clean owned computations *)
    List.iter (fun child -> !clean_node_ref child) node.owned;
    node.owned <- [];
    
    (* Run cleanups in reverse order *)
    List.iter (fun cleanup -> cleanup ()) (List.rev node.cleanups);
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

  (** {1 Update Computation} *)
  
  let update_computation (node : computation) =
    if node.fn = None then ()
    else begin
      clean_node node;
      run_computation node
    end

  (** {1 Run Top} *)
  
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
    
    let rec loop () =
      if rt.updates <> [] || rt.effects <> [] then begin
        while rt.updates <> [] do
          let updates = rt.updates in
          rt.updates <- [];
          List.iter (fun node ->
            try run_top node
            with exn -> B.handle_error exn "memo"
          ) (List.rev updates)
        done;
        
        let effects = rt.effects in
        rt.effects <- [];
        
        let render_effects, user_effects = List.partition (fun e -> not e.user) effects in
        
        List.iter (fun node ->
          try run_top node
          with exn -> B.handle_error exn "effect"
        ) (List.rev render_effects);
        List.iter (fun node ->
          try run_top node
          with exn -> B.handle_error exn "effect"
        ) (List.rev user_effects);
        
        loop ()
      end
    in
    loop ()

  (** {1 Run Updates} *)
  
  let run_updates : 'a. (unit -> 'a) -> bool -> 'a = fun fn init ->
    let rt = get_runtime () in
    
    if rt.in_update then
      fn ()
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
      owned = [];
      cleanups = [];
      owner = rt.owner;
      context = (match rt.owner with Some o -> o.context | None -> []);
      memo_observers = None;
      memo_observer_slots = None;
      memo_observers_len = 0;
      memo_comparator = None;
    } in
    
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
    
    begin match prev_owner with
    | Some parent -> parent.child_owners <- root_owner :: parent.child_owners
    | None -> ()
    end;
    
    rt.owner <- Some root_owner;
    
    let rec dispose_owner owner =
      List.iter dispose_owner (List.rev owner.child_owners);
      owner.child_owners <- [];
      
      List.iter (fun comp -> 
        comp.fn <- None;
        clean_node comp
      ) owner.owned;
      owner.owned <- [];
      
      List.iter (fun cleanup -> cleanup ()) (List.rev owner.cleanups);
      owner.cleanups <- [];
      
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

  (** Register a cleanup function *)
  let on_cleanup fn =
    let rt = get_runtime () in
    match rt.owner with
    | Some owner -> owner.cleanups <- fn :: owner.cleanups
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

  (** {1 Signal API} *)
  
  let create_signal ?comparator initial =
    {
      value = initial;
      observers = [||];
      observer_slots = [||];
      observers_len = 0;
      comparator;
    }

  (** {1 Memo API} *)
  
  let create_memo ~fn ~comparator : computation =
    let comp = create_computation 
      ~fn:(fun prev -> 
        let new_val = fn () in
        (* Check if value changed *)
        let changed = match comparator with
          | Some cmp -> not (cmp prev new_val)
          | None -> prev <> new_val
        in
        if changed then begin
          (* Will mark downstream when computation completes *)
          new_val
        end else
          prev
      )
      ~init:(Obj.repr ())
      ~pure:true
      ~initial_state:Stale
    in
    comp.memo_observers <- Some [||];
    comp.memo_observer_slots <- Some [||];
    comp.memo_comparator <- comparator;
    (* Run immediately (eager evaluation) *)
    update_computation comp;
    comp
end

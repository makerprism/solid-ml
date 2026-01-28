(** Browser Action module tests.
    
    These tests verify the Action module for mutations with cache revalidation.
    
    Run with: make browser-tests
*)

open Solid_ml_browser
open Reactive_core

(* Test helpers *)
external console_log : string -> unit = "log" [@@mel.scope "console"]

let wrap_submit submit v = ignore (submit v)

let set_signal_raw = set_signal
let set_signal s v = ignore (set_signal_raw s v)

let passed = ref 0
let failed = ref 0

let test name fn =
  console_log ("Test: " ^ name);
  try
    fn ();
    incr passed;
    console_log "  PASSED"
  with exn ->
    incr failed;
    console_log ("  FAILED: " ^ Printexc.to_string exn)

(* Async test that completes via callback *)
let test_async name ~timeout_ms fn =
  console_log ("Test (async): " ^ name);
  let completed = ref false in
  
  let on_done success =
    if not !completed then begin
      completed := true;
      if success then begin
        incr passed;
        console_log "  PASSED"
      end else begin
        incr failed;
        console_log "  FAILED"
      end
    end
  in
  
  (* Set timeout for test failure *)
  let timeout_id = Dom.set_timeout (fun () ->
    if not !completed then begin
      completed := true;
      incr failed;
      console_log ("  FAILED: timeout after " ^ string_of_int timeout_ms ^ "ms")
    end
  ) timeout_ms in
  
  try
    fn (fun () -> 
      Dom.clear_timeout timeout_id;
      on_done true
    ) (fun () ->
      Dom.clear_timeout timeout_id;
      on_done false
    )
  with exn ->
    Dom.clear_timeout timeout_id;
    console_log ("  FAILED: " ^ Printexc.to_string exn);
    incr failed

let assert_eq a b =
  if a <> b then failwith "assertion failed: values not equal"

let assert_true b =
  if not b then failwith "assertion failed: expected true"

(* Counter for unique test keys *)
let test_key_counter = ref 0
let unique_key prefix =
  incr test_key_counter;
  prefix ^ "-" ^ string_of_int !test_key_counter

(* Ensure we have a runtime for tests *)
let with_runtime f =
  let ((), dispose) = create_root (fun () -> f ()) in
  dispose ()

(* Helper to create a delayed promise that resolves with a value *)
let delay_resolve (ms : int) (value : 'a) : 'a Dom.promise =
  Dom.promise_make (fun resolve _reject ->
    let _ = Dom.set_timeout (fun () -> resolve value) ms in
    ()
  )

(* Helper to create a delayed promise that rejects with an error *)
let delay_reject (ms : int) (err : exn) : 'a Dom.promise =
  Dom.promise_make (fun _resolve reject ->
    let _ = Dom.set_timeout (fun () -> reject err) ms in
    ()
  )

(* ============ Action Creation Tests ============ *)

let test_action_create () =
  test "Action.create initializes properly" (fun () ->
    with_runtime (fun () ->
      let action = Action.create (fun x -> delay_resolve 50 (x * 2)) in
      
      assert_true (not (Action.is_pending action));
      assert_eq (Action.last_result action) None;
      assert_eq (Action.last_error action) None;
      assert_eq (Action.last_input action) None
    )
  )

let test_action_create_with_revalidation () =
  test "Action.create_with_revalidation sets up keys" (fun () ->
    with_runtime (fun () ->
      let action = Action.create_with_revalidation 
        ~keys:["users"; "posts"]
        (fun x -> delay_resolve 50 x) in
      
      (* Action should be created successfully *)
      assert_true (not (Action.is_pending action))
    )
  )

(* ============ Action.use Tests ============ *)

let test_action_use_sets_pending () =
  test_async "Action.use sets pending state" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 100 (x * 2)) in
      let submit = wrap_submit (Action.use action) in
      
      submit 5;
      
      (* Should be pending immediately after submit *)
      if Action.is_pending action && 
         Action.last_input action = Some 5 then begin
        let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
        ()
      end else
        on_fail ()
    ) in
    dispose_ref := dispose
  )

let test_action_use_resolves () =
  test_async "Action.use resolves and sets result" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 50 (x * 2)) in
      let submit = wrap_submit (Action.use action) in
      
      submit 5;
      
      create_effect (fun () ->
        let pending = get_signal action.pending in
        let result = get_signal action.result in
        
        match (pending, result) with
        | (false, Some 10) ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | (false, Some _) -> on_fail ()
        | (false, None) -> ()  (* initial state, waiting *)
        | (true, _) -> ()  (* still pending *)
      )
    ) in
    dispose_ref := dispose
  )

let test_action_use_rejects () =
  test_async "Action.use catches errors" ~timeout_ms:500 (fun on_pass _on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun _ -> 
        delay_reject 50 (Failure "test error")
      ) in
      let submit = wrap_submit (Action.use action) in
      
      submit ();
      
      create_effect (fun () ->
        let pending = get_signal action.pending in
        let err = get_signal action.error in
        
        match (pending, err) with
        | (false, Some _) ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | (false, None) -> ()  (* initial state *)
        | (true, _) -> ()  (* still pending *)
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Action.use_submission Tests ============ *)

let test_action_use_submission () =
  test_async "Action.use_submission tracks state" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 50 ("got: " ^ x)) in
      let submit = wrap_submit (Action.use action) in
      let submission = Action.use_submission action in
      
      submit "hello";
      
      create_effect (fun () ->
        let pending = get_signal submission.pending in
        let result = get_signal submission.result in
        let input = get_signal submission.input in
        
        match (pending, result, input) with
        | (false, Some "got: hello", Some "hello") ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | (false, Some _, _) -> on_fail ()
        | _ -> ()  (* waiting *)
      )
    ) in
    dispose_ref := dispose
  )

let test_action_submission_clear () =
  test_async "Action submission.clear resets state" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 30 x) in
      let submit = wrap_submit (Action.use action) in
      let submission = Action.use_submission action in
      
      submit 42;
      
      let cleared = ref false in
      create_effect (fun () ->
        let pending = get_signal submission.pending in
        let result = get_signal submission.result in
        
        if not pending && result = Some 42 && not !cleared then begin
          cleared := true;
          submission.clear ();
          ()
        end else if !cleared then begin
          (* After clear, should be None *)
          if result = None then begin
            let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
            ()
          end else
            on_fail ()
        end
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Action.use_async Tests ============ *)

let test_action_use_async () =
  test_async "Action.use_async returns promise" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 50 (x + 1)) in
      let submit_async = Action.use_async action in
      
      let promise = submit_async 10 in
      
      Dom.promise_on_complete promise
        ~on_success:(fun result ->
          if result = 11 then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        )
        ~on_error:(fun _ -> on_fail ())
    ) in
    dispose_ref := dispose
  )

(* ============ Action.make Tests ============ *)

let test_action_make () =
  test_async "Action.make creates and uses in one step" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let call_count = ref 0 in
      let submit = Action.make (fun x ->
        incr call_count;
        delay_resolve 50 (x * 3)
      ) in
      
      submit 7;
      
      let _ = Dom.set_timeout (fun () ->
        if !call_count = 1 then begin
          !dispose_ref ();
          on_pass ()
        end else
          on_fail ()
      ) 100 in
      ()
    ) in
    dispose_ref := dispose
  )

(* ============ Action.chain Tests ============ *)

let test_action_chain () =
  test_async "Action.chain runs actions in sequence" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action1 = Action.create (fun x -> delay_resolve 30 (x + 10)) in
      let action2 = Action.create (fun x -> delay_resolve 30 (x * 2)) in
      
      let chained = Action.chain action1 action2 in
      let submit = wrap_submit (Action.use chained) in
      
      submit 5;
      
      create_effect (fun () ->
        let pending = get_signal chained.pending in
        let result = get_signal chained.result in
        
        match (pending, result) with
        | (false, Some 30) ->  (* (5 + 10) * 2 = 30 *)
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | (false, Some _) -> on_fail ()
        | _ -> ()  (* waiting *)
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Action.clear Tests ============ *)

let test_action_clear () =
  test_async "Action.clear resets action state" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let action = Action.create (fun x -> delay_resolve 30 x) in
      let submit = wrap_submit (Action.use action) in
      
      submit "test";
      
      let _ = Dom.set_timeout (fun () ->
        (* After action completes, verify result then clear *)
        if Action.last_result action = Some "test" then begin
          Action.clear action;
          if Action.last_result action = None &&
             Action.last_input action = None then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        end else
          on_fail ()
      ) 100 in
      ()
    ) in
    dispose_ref := dispose
  )

(* ============ Registry Tests ============ *)

let test_registry_revalidation () =
  test_async "Action triggers revalidation on success" ~timeout_ms:1000 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let refetch_count = ref 0 in
      (* Use a unique key to avoid interference from other tests *)
      let key = unique_key "test-resource" in
      
      (* Create an async resource and register it *)
      let resource = Async.create_once (fun () ->
        incr refetch_count;
        delay_resolve 30 "data"
      ) in
      Action.register_async ~key resource;
      
      (* Create action that revalidates this resource *)
      let action = Action.create_with_revalidation
        ~keys:[key]
        (fun () -> delay_resolve 30 "done") in
      let submit = wrap_submit (Action.use action) in
      
      (* Wait for initial fetch, then submit action *)
      let _ = Dom.set_timeout (fun () ->
        let initial_count = !refetch_count in
        submit ();
        
        (* Wait for action to complete and trigger revalidation *)
        let _ = Dom.set_timeout (fun () ->
          if !refetch_count > initial_count then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        ) 150 in
        ()
      ) 100 in
      ()
    ) in
    dispose_ref := dispose
  )

let test_registry_manual_revalidate () =
  test_async "Action.revalidate manually triggers refetch" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let refetch_count = ref 0 in
      (* Use a unique key to avoid interference from other tests *)
      let key = unique_key "manual-test" in
      
      let resource = Async.create_once (fun () ->
        incr refetch_count;
        delay_resolve 30 "data"
      ) in
      Action.register_async ~key resource;
      
      (* Wait for initial fetch *)
      let _ = Dom.set_timeout (fun () ->
        let initial_count = !refetch_count in
        Action.revalidate ~key;
        
        (* Wait for refetch *)
        let _ = Dom.set_timeout (fun () ->
          if !refetch_count > initial_count then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        ) 100 in
        ()
      ) 100 in
      ()
    ) in
    dispose_ref := dispose
  )

let test_registry_revalidate_all () =
  test_async "Action.revalidate_all triggers all refetches" ~timeout_ms:500 (fun on_pass on_fail ->
    (* Note: We don't clear registry here as it would interfere with parallel tests.
       Instead, we use unique keys and verify that OUR resources are refetched. *)
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let count1 = ref 0 in
      let count2 = ref 0 in
      let key1 = unique_key "res1" in
      let key2 = unique_key "res2" in
      
      let resource1 = Async.create_once (fun () ->
        incr count1;
        delay_resolve 20 "a"
      ) in
      let resource2 = Async.create_once (fun () ->
        incr count2;
        delay_resolve 20 "b"
      ) in
      
      Action.register_async ~key:key1 resource1;
      Action.register_async ~key:key2 resource2;
      
      (* Wait for initial fetches *)
      let _ = Dom.set_timeout (fun () ->
        let initial1 = !count1 in
        let initial2 = !count2 in
        
        Action.revalidate_all ();
        
        (* Wait for refetches *)
        let _ = Dom.set_timeout (fun () ->
          if !count1 > initial1 && !count2 > initial2 then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        ) 100 in
        ()
      ) 100 in
      ()
    ) in
    dispose_ref := dispose
  )

(* ============ Action.with_optimistic Tests ============ *)

let test_action_with_optimistic_success () =
  test_async "Action.with_optimistic applies update on success" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let state = create_signal 0 in
      
      let action = Action.create (fun x -> delay_resolve 50 x) in
      
      let submit = wrap_submit (Action.with_optimistic action ~optimistic:(fun new_val ->
        let old_val = peek_signal state in
        set_signal state new_val;
        (* Return rollback function *)
        fun () -> set_signal state old_val
      )) in
      
      submit 42;
      
      (* Optimistic update should be applied immediately *)
      if get_signal state = 42 then begin
        (* Wait for action to complete *)
        let _ = Dom.set_timeout (fun () ->
          (* State should still be 42 (no rollback on success) *)
          if get_signal state = 42 then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        ) 100 in
        ()
      end else
        on_fail ()
    ) in
    dispose_ref := dispose
  )

let test_action_with_optimistic_rollback () =
  test_async "Action.with_optimistic rolls back on error" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let state = create_signal 100 in
      
      let action = Action.create (fun _ -> 
        delay_reject 50 (Failure "error")
      ) in
      
      let submit = wrap_submit (Action.with_optimistic action ~optimistic:(fun new_val ->
        let old_val = peek_signal state in
        set_signal state new_val;
        (* Return rollback function *)
        fun () -> set_signal state old_val
      )) in
      
      submit 999;
      
      (* Optimistic update should be applied immediately *)
      if get_signal state = 999 then begin
        (* Wait for action to fail and rollback *)
        let _ = Dom.set_timeout (fun () ->
          (* State should be rolled back to 100 *)
          if get_signal state = 100 then begin
            !dispose_ref ();
            on_pass ()
          end else
            on_fail ()
        ) 100 in
        ()
      end else
        on_fail ()
    ) in
    dispose_ref := dispose
  )

(* ============ Action.create_simple Tests ============ *)

let test_action_create_simple () =
  test_async "Action.create_simple for unit input" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let counter = ref 0 in
      let action = Action.create_simple (fun () ->
        incr counter;
        delay_resolve 50 !counter
      ) in
      let submit = wrap_submit (Action.use action) in
      
      submit ();
      
      create_effect (fun () ->
        let result = get_signal action.result in
        match result with
        | Some 1 ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | Some _ -> on_fail ()
        | None -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Run All Tests ============ *)

let () =
  console_log "\n=== Browser Action Tests ===\n";
  
  console_log "-- Action Creation Tests --";
  test_action_create ();
  test_action_create_with_revalidation ();
  
  console_log "\n-- Action.use Tests --";
  test_action_use_sets_pending ();
  test_action_use_resolves ();
  test_action_use_rejects ();
  
  console_log "\n-- Action.use_submission Tests --";
  test_action_use_submission ();
  test_action_submission_clear ();
  
  console_log "\n-- Action.use_async Tests --";
  test_action_use_async ();
  
  console_log "\n-- Action.make Tests --";
  test_action_make ();
  
  console_log "\n-- Action.chain Tests --";
  test_action_chain ();
  
  console_log "\n-- Action.clear Tests --";
  test_action_clear ();
  
  console_log "\n-- Registry Tests --";
  test_registry_revalidation ();
  test_registry_manual_revalidate ();
  test_registry_revalidate_all ();
  
  console_log "\n-- Action.with_optimistic Tests --";
  test_action_with_optimistic_success ();
  test_action_with_optimistic_rollback ();
  
  console_log "\n-- Action.create_simple Tests --";
  test_action_create_simple ();
  
  (* Wait for async tests to complete before printing summary *)
  let _ = Dom.set_timeout (fun () ->
    console_log "\n=== Action Results ===";
    console_log ("Passed: " ^ string_of_int !passed);
    console_log ("Failed: " ^ string_of_int !failed);
    
    if !failed > 0 then
      console_log "\n*** SOME ACTION TESTS FAILED ***"
    else
      console_log "\n=== All action tests passed! ==="
  ) 3000 in
  ()

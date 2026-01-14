(** Browser Async module tests.
    
    These tests verify the Async module for Promise-based data fetching.
    
    Run with: make browser-tests
*)

open Solid_ml_browser
open Reactive_core

(* Test helpers *)
external console_log : string -> unit = "log" [@@mel.scope "console"]

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

(* ============ Async State Tests ============ *)

let test_async_initial_pending () =
  test "Async starts in Pending state" (fun () ->
    with_runtime (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 100 42) in
      
      assert_true (Async.is_pending async_val);
      assert_true (not (Async.is_ready async_val));
      assert_true (not (Async.is_error async_val))
    )
  )

let test_async_read_state () =
  test "Async.read returns current state" (fun () ->
    with_runtime (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 100 "hello") in
      
      match Async.read async_val with
      | Async.Pending -> ()  (* expected *)
      | _ -> failwith "Expected Pending state"
    )
  )

let test_async_get_or_default () =
  test "Async.get_or returns default when pending" (fun () ->
    with_runtime (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 100 42) in
      
      let value = Async.get_or async_val ~default:(-1) in
      assert_eq value (-1)
    )
  )

(* ============ Async Resolution Tests ============ *)

let test_async_resolves () =
  test_async "Async resolves to Ready state" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 50 "success") in
      
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready data ->
          if data = "success" then begin
            (* Need to dispose after effect completes *)
            let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
            ()
          end else
            on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()  (* waiting *)
      )
    ) in
    dispose_ref := dispose
  )

let test_async_rejects () =
  test_async "Async catches errors" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let async_val = Async.create (fun () -> 
        delay_reject 50 (Failure "test error")
      ) in
      
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Error _ ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | Async.Ready _ -> on_fail ()
        | Async.Pending -> ()  (* waiting *)
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async Reactivity Tests ============ *)

let test_async_refetches_on_signal_change () =
  test_async "Async refetches when dependencies change" ~timeout_ms:1000 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let source = create_signal 1 in
      let fetch_count = ref 0 in
      
      let async_val = Async.create (fun () ->
        incr fetch_count;
        let v = get_signal source in
        delay_resolve 50 (v * 10)
      ) in
      
      let ready_count = ref 0 in
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready data ->
          incr ready_count;
          if !ready_count = 1 then begin
            (* First resolution - trigger refetch *)
            if data = 10 then
              set_signal source 2
            else
              on_fail ()
          end else if !ready_count = 2 then begin
            (* Second resolution - verify refetch happened *)
            if data = 20 && !fetch_count >= 2 then begin
              let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
              ()
            end else
              on_fail ()
          end
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.create_once Tests ============ *)

let test_async_create_once () =
  test_async "Async.create_once fetches only once" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let fetch_count = ref 0 in
      
      let async_val = Async.create_once (fun () ->
        incr fetch_count;
        delay_resolve 50 "done"
      ) in
      
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready _ ->
          if !fetch_count = 1 then begin
            let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
            ()
          end else
            on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.create_with_source Tests ============ *)

let test_async_with_source () =
  test_async "Async.create_with_source tracks source signal" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let user_id = create_signal 1 in
      
      let async_val = Async.create_with_source user_id (fun id ->
        delay_resolve 50 ("user_" ^ string_of_int id)
      ) in
      
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready data ->
          if data = "user_1" then begin
            let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
            ()
          end else
            on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.refetch Tests ============ *)

let test_async_manual_refetch () =
  test_async "Async.refetch manually triggers refetch" ~timeout_ms:1000 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let counter = ref 0 in
      
      let async_val = Async.create_once (fun () ->
        incr counter;
        delay_resolve 50 !counter
      ) in
      
      let ready_count = ref 0 in
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready data ->
          incr ready_count;
          if !ready_count = 1 then begin
            (* First resolution - trigger manual refetch *)
            if data = 1 then
              Async.refetch async_val
            else
              on_fail ()
          end else if !ready_count = 2 then begin
            (* Second resolution - verify refetch happened *)
            if data = 2 then begin
              let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
              ()
            end else
              on_fail ()
          end
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.data and Async.error Tests ============ *)

let test_async_data_accessor () =
  test_async "Async.data returns Some when ready" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 50 42) in
      
      (* Initially None *)
      (match Async.data async_val with
       | None -> ()
       | Some _ -> on_fail ());
      
      create_effect (fun () ->
        match Async.read async_val with
        | Async.Ready _ ->
          (match Async.data async_val with
           | Some 42 -> 
             let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
             ()
           | _ -> on_fail ())
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.map Tests ============ *)

let test_async_map () =
  test_async "Async.map transforms ready value" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 50 10) in
      
      create_effect (fun () ->
        match Async.map (fun x -> x * 2) async_val with
        | Async.Ready 20 ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | Async.Ready _ -> on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.both Tests ============ *)

let test_async_both () =
  test_async "Async.both combines two async values" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let a = Async.create (fun () -> delay_resolve 30 1) in
      let b = Async.create (fun () -> delay_resolve 50 2) in
      
      create_effect (fun () ->
        match Async.both a b with
        | Async.Ready (x, y) when x = 1 && y = 2 ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | Async.Ready _ -> on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.all Tests ============ *)

let test_async_all () =
  test_async "Async.all combines list of async values" ~timeout_ms:500 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let asyncs = [
        Async.create (fun () -> delay_resolve 20 1);
        Async.create (fun () -> delay_resolve 40 2);
        Async.create (fun () -> delay_resolve 60 3);
      ] in
      
      create_effect (fun () ->
        match Async.all asyncs with
        | Async.Ready [1; 2; 3] ->
          let _ = Dom.set_timeout (fun () -> !dispose_ref (); on_pass ()) 0 in
          ()
        | Async.Ready _ -> on_fail ()
        | Async.Error _ -> on_fail ()
        | Async.Pending -> ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.on_ready Tests ============ *)

let test_async_on_ready () =
  test_async "Async.on_ready callback fires when ready" ~timeout_ms:1000 (fun on_pass on_fail ->
    let dispose_ref = ref (fun () -> ()) in
    let (_, dispose) = create_root (fun () ->
      let async_val = Async.create (fun () -> 
        delay_resolve 50 "hello"
      ) in
      
      Async.on_ready async_val (fun data ->
        if data = "hello" then begin
          let _ = Dom.set_timeout (fun () -> 
            !dispose_ref (); 
            on_pass ()
          ) 0 in
          ()
        end else
          on_fail ()
      )
    ) in
    dispose_ref := dispose
  )

(* ============ Async.dispose Tests ============ *)

let test_async_dispose () =
  test "Async.dispose stops updates" (fun () ->
    with_runtime (fun () ->
      let async_val = Async.create (fun () -> delay_resolve 100 42) in
      
      (* Dispose immediately *)
      Async.dispose async_val;
      
      (* Should still be pending (disposed before resolution) *)
      assert_true (Async.is_pending async_val)
    )
  )

(* ============ Run All Tests ============ *)

let () =
  console_log "\n=== Browser Async Tests ===\n";
  
  console_log "-- Async State Tests --";
  test_async_initial_pending ();
  test_async_read_state ();
  test_async_get_or_default ();
  
  console_log "\n-- Async Resolution Tests --";
  test_async_resolves ();
  test_async_rejects ();
  
  console_log "\n-- Async Reactivity Tests --";
  test_async_refetches_on_signal_change ();
  
  console_log "\n-- Async.create_once Tests --";
  test_async_create_once ();
  
  console_log "\n-- Async.create_with_source Tests --";
  test_async_with_source ();
  
  console_log "\n-- Async.refetch Tests --";
  test_async_manual_refetch ();
  
  console_log "\n-- Async.data Tests --";
  test_async_data_accessor ();
  
  console_log "\n-- Async.map Tests --";
  test_async_map ();
  
  console_log "\n-- Async.both Tests --";
  test_async_both ();
  
  console_log "\n-- Async.all Tests --";
  test_async_all ();
  
  console_log "\n-- Async.on_ready Tests --";
  test_async_on_ready ();
  
  console_log "\n-- Async.dispose Tests --";
  test_async_dispose ();
  
  (* Wait a bit for async tests to complete before printing summary *)
  let _ = Dom.set_timeout (fun () ->
    console_log "\n=== Async Results ===";
    console_log ("Passed: " ^ string_of_int !passed);
    console_log ("Failed: " ^ string_of_int !failed);
    
    if !failed > 0 then
      console_log "\n*** SOME ASYNC TESTS FAILED ***"
    else
      console_log "\n=== All async tests passed! ==="
  ) 2000 in
  ()

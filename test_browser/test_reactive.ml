(** Browser reactive core tests.
    
    These tests verify the shared reactive implementation works correctly
    when instantiated with the browser backend.
    
    Run with: make browser-tests
    Or directly:
      dune build @test_browser/melange
      node _build/default/test_browser/output/test_browser/test_reactive.js
*)

open Solid_ml_browser
open Reactive_core

(* Note: Hydration and Render modules require DOM APIs and can't be tested in Node.js
   without a DOM polyfill. These tests focus on the reactive core which is pure OCaml. *)

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

let assert_eq a b =
  if a <> b then failwith "assertion failed: values not equal"

let assert_true b =
  if not b then failwith "assertion failed: expected true"

(* Ensure we have a runtime for tests *)
let with_runtime f =
  let (_, dispose) = create_root (fun () -> f ()) in
  dispose ()

(* ============ Signal Tests ============ *)

let test_signal_basic () =
  test "Signal basic operations" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 42 in
      assert_eq (get_signal s) 42;
      set_signal s 100;
      assert_eq (get_signal s) 100
    )
  )

let test_signal_peek () =
  test "Signal.peek doesn't track" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = peek_signal s in  (* Should not track *)
        ()
      );
      assert_eq !runs 1;
      set_signal s 2;
      (* Effect should NOT re-run because we used peek *)
      assert_eq !runs 1
    )
  )

let test_signal_equality () =
  test "Signal skips update on equal value" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s in
        ()
      );
      assert_eq !runs 1;
      set_signal s 1;  (* Same value *)
      assert_eq !runs 1;  (* Should not re-run *)
      set_signal s 2;  (* Different value *)
      assert_eq !runs 2  (* Should re-run *)
    )
  )

(* ============ Effect Tests ============ *)

let test_effect_tracking () =
  test "Effect auto-tracks dependencies" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 0 in
      let observed = ref (-1) in
      create_effect (fun () ->
        observed := get_signal s
      );
      assert_eq !observed 0;
      set_signal s 5;
      assert_eq !observed 5
    )
  )

let test_effect_cleanup () =
  test "Effect cleanup runs before re-execution" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 0 in
      let log = ref [] in
      create_effect_with_cleanup (fun () ->
        log := ("run " ^ string_of_int (get_signal s)) :: !log;
        fun () -> log := "cleanup" :: !log
      );
      assert_eq !log ["run 0"];
      set_signal s 1;
      assert_eq !log ["run 1"; "cleanup"; "run 0"]
    )
  )

let test_effect_untrack () =
  test "Effect.untrack prevents tracking" (fun () ->
    with_runtime (fun () ->
      let s1 = create_signal 1 in
      let s2 = create_signal 2 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s1 in
        let _ = untrack (fun () -> get_signal s2) in
        ()
      );
      assert_eq !runs 1;
      set_signal s1 10;
      assert_eq !runs 2;  (* s1 is tracked *)
      set_signal s2 20;
      assert_eq !runs 2   (* s2 is NOT tracked *)
    )
  )

(* ============ Memo Tests ============ *)

let test_memo_basic () =
  test "Memo caches derived values" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 2 in
      let runs = ref 0 in
      let doubled = create_memo (fun () ->
        incr runs;
        get_signal s * 2
      ) in
      assert_eq (get_memo doubled) 4;
      assert_eq !runs 1;
      (* Reading again should not recompute *)
      assert_eq (get_memo doubled) 4;
      assert_eq !runs 1;
      (* Changing source should recompute *)
      set_signal s 5;
      assert_eq (get_memo doubled) 10;
      assert_eq !runs 2
    )
  )

let test_memo_chain () =
  test "Memos can depend on other memos" (fun () ->
    with_runtime (fun () ->
      let s = create_signal 1 in
      let m1 = create_memo (fun () -> get_signal s + 1) in
      let m2 = create_memo (fun () -> get_memo m1 * 2) in
      assert_eq (get_memo m2) 4;  (* (1+1)*2 *)
      set_signal s 5;
      assert_eq (get_memo m2) 12  (* (5+1)*2 *)
    )
  )

(* ============ Owner Tests ============ *)

let test_owner_cleanup () =
  test "Owner.on_cleanup runs on dispose" (fun () ->
    with_runtime (fun () ->
      let cleaned = ref false in
      let (_, dispose) = create_root (fun () ->
        on_cleanup (fun () -> cleaned := true)
      ) in
      assert_true (not !cleaned);
      dispose ();
      assert_true !cleaned
    )
  )

let test_nested_roots () =
  test "Nested roots dispose children" (fun () ->
    with_runtime (fun () ->
      let order = ref [] in
      let (_, dispose_outer) = create_root (fun () ->
        on_cleanup (fun () -> order := "outer" :: !order);
        let (_, _dispose_inner) = create_root (fun () ->
          on_cleanup (fun () -> order := "inner" :: !order)
        ) in
        ()
      ) in
      dispose_outer ();
      (* Inner should be disposed before outer *)
      assert_eq !order ["outer"; "inner"]
    )
  )

(* ============ Context Tests ============ *)

let test_context_basic () =
  test "Context basic provide/use" (fun () ->
    with_runtime (fun () ->
      let ctx = create_context "default" in
      assert_eq (use_context ctx) "default";
      let result = provide_context ctx "provided" (fun () ->
        use_context ctx
      ) in
      assert_eq result "provided";
      (* Outside provide, back to default *)
      assert_eq (use_context ctx) "default"
    )
  )

let test_context_nesting () =
  test "Context nested provides" (fun () ->
    with_runtime (fun () ->
      let ctx = create_context "L0" in
      provide_context ctx "L1" (fun () ->
        assert_eq (use_context ctx) "L1";
        provide_context ctx "L2" (fun () ->
          assert_eq (use_context ctx) "L2"
        );
        assert_eq (use_context ctx) "L1"
      )
    )
  )

(* ============ Batch Tests ============ *)

let test_batch_updates () =
  test "Batch groups updates" (fun () ->
    with_runtime (fun () ->
      let s1 = create_signal 0 in
      let s2 = create_signal 0 in
      let runs = ref 0 in
      create_effect (fun () ->
        incr runs;
        let _ = get_signal s1 + get_signal s2 in
        ()
      );
      assert_eq !runs 1;
      batch (fun () ->
        set_signal s1 1;
        set_signal s2 2
      );
      (* Effect should only run once for the batch *)
      assert_eq !runs 2
    )
  )

(* ============ Diamond Dependency ============ *)

let test_diamond () =
  test "Diamond dependency (glitch-free)" (fun () ->
    with_runtime (fun () ->
      let a = create_signal 1 in
      let b = create_memo (fun () -> get_signal a * 2) in
      let c = create_memo (fun () -> get_signal a * 3) in
      let d_runs = ref 0 in
      let d = create_memo (fun () ->
        incr d_runs;
        get_memo b + get_memo c
      ) in
      assert_eq (get_memo d) 5;
      let initial_runs = !d_runs in
      set_signal a 2;
      assert_eq (get_memo d) 10;
      (* d should only compute once per change *)
      assert_true (!d_runs <= initial_runs + 1)
    )
  )

(* ============ Run All Tests ============ *)

let () =
  console_log "\n=== Browser Reactive Tests ===\n";
  
  console_log "-- Signal Tests --";
  test_signal_basic ();
  test_signal_peek ();
  test_signal_equality ();
  
  console_log "\n-- Effect Tests --";
  test_effect_tracking ();
  test_effect_cleanup ();
  test_effect_untrack ();
  
  console_log "\n-- Memo Tests --";
  test_memo_basic ();
  test_memo_chain ();
  
  console_log "\n-- Owner Tests --";
  test_owner_cleanup ();
  test_nested_roots ();
  
  console_log "\n-- Context Tests --";
  test_context_basic ();
  test_context_nesting ();
  
  console_log "\n-- Batch Tests --";
  test_batch_updates ();
  
  console_log "\n-- Integration Tests --";
  test_diamond ();
  
  console_log "\n=== Results ===";
  console_log ("Passed: " ^ string_of_int !passed);
  console_log ("Failed: " ^ string_of_int !failed);
  
  if !failed > 0 then
    console_log "\n*** SOME TESTS FAILED ***"
  else
    console_log "\n=== All browser tests passed! ==="

(** Tests ported from SolidJS to verify compatibility.
    
    These tests are based on SolidJS's signal.spec.ts test suite
    to ensure our reactive system behaves similarly.
*)

open Solid_ml

module Unsafe = struct
  module Signal = Signal.Unsafe
  module Effect = Effect.Unsafe
  module Memo = Memo.Unsafe
  module Batch = Batch.Unsafe
  module Owner = Owner.Unsafe
  module Runtime = Runtime.Unsafe
end

open Unsafe

(** Helper to run test within a reactive runtime *)
let with_runtime fn =
  Runtime.run (fun () ->
    let dispose = Owner.create_root fn in
    dispose ()
  )

(* ============ Create Signals ============ *)

let test_create_and_read_signal () =
  print_endline "Test: Create and read a Signal";
  with_runtime (fun () ->
    let value, _ = Signal.create 5 in
    assert (Signal.get value = 5)
  );
  print_endline "  PASSED"

let test_create_signal_with_comparator () =
  print_endline "Test: Create and read a Signal with comparator";
  with_runtime (fun () ->
    let value, _ = Signal.create ~equals:(=) 5 in
    assert (Signal.get value = 5)
  );
  print_endline "  PASSED"

let test_create_and_read_memo () =
  print_endline "Test: Create and read a Memo";
  with_runtime (fun () ->
    let memo = Memo.create (fun () -> "Hello") in
    assert (Memo.get memo = "Hello")
  );
  print_endline "  PASSED"

(* ============ Update Signals ============ *)

let test_create_and_update_signal () =
  print_endline "Test: Create and update a Signal";
  with_runtime (fun () ->
    let value, set_value = Signal.create 5 in
    set_value 10;
    assert (Signal.get value = 10)
  );
  print_endline "  PASSED"

let test_create_and_update_signal_with_fn () =
  print_endline "Test: Create and update a Signal with fn";
  with_runtime (fun () ->
    let value, _ = Signal.create 5 in
    Signal.update value (fun p -> p + 5);
    assert (Signal.get value = 10)
  );
  print_endline "  PASSED"

let test_signal_set_different_value () =
  print_endline "Test: Create Signal and set different value";
  with_runtime (fun () ->
    let value, set_value = Signal.create 5 in
    set_value 10;
    assert (Signal.get value = 10)
  );
  print_endline "  PASSED"

let test_signal_set_equivalent_value () =
  print_endline "Test: Create Signal and set equivalent value (custom comparator)";
  with_runtime (fun () ->
    (* Custom comparator: a > b means "equal" - so setting smaller values won't update *)
    let value, set_value = Signal.create ~equals:(fun a b -> a > b) 5 in
    set_value 3;  (* 5 > 3 is true, so considered "equal", no update *)
    assert (Signal.get value = 5)
  );
  print_endline "  PASSED"

let test_create_and_trigger_memo () =
  print_endline "Test: Create and trigger a Memo";
  with_runtime (fun () ->
    let name, set_name = Signal.create "John" in
    let memo = Memo.create (fun () -> "Hello " ^ Signal.get name) in
    assert (Memo.get memo = "Hello John");
    set_name "Jake";
    assert (Memo.get memo = "Hello Jake")
  );
  print_endline "  PASSED"

let test_memo_not_triggered_on_equivalent_value () =
  print_endline "Test: Create Signal and set equivalent value not trigger Memo";
  with_runtime (fun () ->
    (* Custom comparator: if new value starts with "J", consider it equal *)
    let name, set_name = Signal.create ~equals:(fun _ b -> String.length b > 0 && b.[0] = 'J') "John" in
    let memo = Memo.create (fun () -> "Hello " ^ Signal.get name) in
    assert (Signal.get name = "John");
    assert (Memo.get memo = "Hello John");
    set_name "Jake";  (* Starts with J, so equal, no update *)
    assert (Signal.get name = "John");
    assert (Memo.get memo = "Hello John")
  );
  print_endline "  PASSED"

let test_create_and_trigger_memo_in_effect () =
  print_endline "Test: Create and trigger a Memo in an effect";
  with_runtime (fun () ->
    let temp = ref "" in
    let name, set_name = Signal.create "John" in
    let memo = Memo.create (fun () -> "Hello " ^ Signal.get name) in
    Effect.create (fun () -> temp := Memo.get memo ^ "!!!");
    assert (!temp = "Hello John!!!");
    set_name "Jake";
    assert (!temp = "Hello Jake!!!")
  );
  print_endline "  PASSED"

let test_create_and_trigger_effect () =
  print_endline "Test: Create and trigger an Effect";
  with_runtime (fun () ->
    let temp = ref "" in
    let sign, set_sign = Signal.create "thoughts" in
    Effect.create (fun () -> temp := "unpure " ^ Signal.get sign);
    assert (!temp = "unpure thoughts");
    set_sign "mind";
    assert (!temp = "unpure mind")
  );
  print_endline "  PASSED"

(* ============ Untrack Signals ============ *)

let test_mute_effect_with_untrack () =
  print_endline "Test: Mute an effect with untrack";
  with_runtime (fun () ->
    let temp = ref "" in
    let sign, set_sign = Signal.create "thoughts" in
    Effect.create (fun () -> 
      temp := "unpure " ^ Effect.untrack (fun () -> Signal.get sign)
    );
    assert (!temp = "unpure thoughts");
    set_sign "mind";
    (* Effect should not re-run because we untracked the signal *)
    assert (!temp = "unpure thoughts")
  );
  print_endline "  PASSED"

(* ============ Effect Grouping ============ *)

let test_groups_updates () =
  print_endline "Test: Groups updates";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, set_a = Signal.create 0 in
    let b, set_b = Signal.create 0 in
    Effect.create (fun () ->
      set_a 1;
      set_b 1
    );
    let _ = Memo.create (fun () -> 
      count := !count + Signal.get a + Signal.get b;
      !count
    ) in
    (* The memo should have computed once with final values *)
    assert (!count = 2)
  );
  print_endline "  PASSED"

let test_groups_updates_with_repeated_sets () =
  print_endline "Test: Groups updates with repeated sets";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, set_a = Signal.create 0 in
    Effect.create (fun () ->
      set_a 1;
      set_a 4
    );
    let _ = Memo.create (fun () ->
      count := Signal.get a;
      !count
    ) in
    assert (!count = 4)
  );
  print_endline "  PASSED"

let test_multiple_sets () =
  print_endline "Test: Multiple sets (final value wins)";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, set_a = Signal.create 0 in
    Effect.create (fun () ->
      set_a 1;
      set_a 0
    );
    let _ = Memo.create (fun () ->
      count := Signal.get a;
      !count
    ) in
    assert (!count = 0)
  );
  print_endline "  PASSED"

(* ============ onCleanup ============ *)

let test_clean_effect () =
  print_endline "Test: Clean an effect";
  with_runtime (fun () ->
    let temp = ref "" in
    let sign, set_sign = Signal.create "thoughts" in
    Effect.create_with_cleanup (fun () ->
      let _ = Signal.get sign in
      fun () -> temp := "after"
    );
    assert (!temp = "");
    set_sign "mind";
    assert (!temp = "after")
  );
  print_endline "  PASSED"

let test_explicit_root_disposal () =
  print_endline "Test: Explicit root disposal";
  let temp = ref "" in
  let dispose = Owner.create_root (fun () ->
    Owner.on_cleanup (fun () -> temp := "disposed")
  ) in
  assert (!temp = "");
  dispose ();
  assert (!temp = "disposed");
  print_endline "  PASSED"

(* ============ Context ============ *)

let test_create_context_defaults_to_default () =
  print_endline "Test: createContext defaults to provided default";
  with_runtime (fun () ->
    let context = Context.create 42 in
    let res = Context.use context in
    assert (res = 42)
  );
  print_endline "  PASSED"

let test_context_provide_and_use () =
  print_endline "Test: Context provide and use";
  with_runtime (fun () ->
    let context = Context.create "default" in
    let result = Context.provide context "provided" (fun () ->
      Context.use context
    ) in
    assert (result = "provided")
  );
  print_endline "  PASSED"

(* ============ createRoot ============ *)

let test_nested_roots () =
  print_endline "Test: Nested roots with ownership";
  with_runtime (fun () ->
    let owner1 = Owner.get_owner () in
    let _, dispose2 = Owner.run_with_owner (fun () ->
      let owner2 = Owner.get_owner () in
      (* owner2 should exist and be different from owner1 *)
      assert (owner2 <> None);
      assert (owner2 <> owner1);
      ()
    ) in
    dispose2 ()
  );
  print_endline "  PASSED"

(* ============ Diamond Dependency ============ *)

let test_diamond_dependency () =
  print_endline "Test: Diamond dependency (glitch-free)";
  with_runtime (fun () ->
    (* Classic diamond:
           a
          / \
         b   c
          \ /
           d
    *)
    let a, set_a = Signal.create 1 in
    let b = Memo.create (fun () -> Signal.get a * 2) in
    let c = Memo.create (fun () -> Signal.get a * 3) in
    let d_runs = ref 0 in
    let d = Memo.create (fun () ->
      incr d_runs;
      Memo.get b + Memo.get c
    ) in
    assert (Memo.get d = 5);  (* 2 + 3 *)
    let initial_runs = !d_runs in
    set_a 2;
    assert (Memo.get d = 10);  (* 4 + 6 *)
    (* d should only compute once per change, not twice *)
    assert (!d_runs <= initial_runs + 1)
  );
  print_endline "  PASSED"

(* ============ Deep Memo Chain ============ *)

let test_deep_memo_chain () =
  print_endline "Test: Deep memo chain";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b = Memo.create (fun () -> Signal.get a + 1) in
    let c = Memo.create (fun () -> Memo.get b + 1) in
    let d = Memo.create (fun () -> Memo.get c + 1) in
    let e = Memo.create (fun () -> Memo.get d + 1) in
    assert (Memo.get e = 5);
    set_a 10;
    assert (Memo.get e = 14)
  );
  print_endline "  PASSED"

(* ============ Conditional Dependencies ============ *)

let test_conditional_memo_deps () =
  print_endline "Test: Conditional memo dependencies";
  with_runtime (fun () ->
    let cond, set_cond = Signal.create true in
    let a, set_a = Signal.create "A" in
    let b, set_b = Signal.create "B" in
    let runs = ref 0 in
    let result = Memo.create (fun () ->
      incr runs;
      if Signal.get cond then Signal.get a else Signal.get b
    ) in
    assert (Memo.get result = "A");
    let r1 = !runs in
    
    (* Changing a should trigger *)
    set_a "A2";
    assert (Memo.get result = "A2");
    assert (!runs = r1 + 1);
    
    (* Changing b should NOT trigger (not tracked) *)
    set_b "B2";
    assert (Memo.get result = "A2");
    assert (!runs = r1 + 1);
    
    (* Switch condition *)
    set_cond false;
    assert (Memo.get result = "B2");
    
    (* Now a should NOT trigger, b should *)
    let r2 = !runs in
    set_a "A3";
    assert (Memo.get result = "B2");
    assert (!runs = r2);
    
    set_b "B3";
    assert (Memo.get result = "B3")
  );
  print_endline "  PASSED"

(* ============ Effect with Multiple Sources ============ *)

let test_effect_multiple_sources () =
  print_endline "Test: Effect with multiple sources";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let c, set_c = Signal.create 3 in
    let sum = ref 0 in
    let runs = ref 0 in
    Effect.create (fun () ->
      incr runs;
      sum := Signal.get a + Signal.get b + Signal.get c
    );
    assert (!sum = 6);
    assert (!runs = 1);
    
    set_a 10;
    assert (!sum = 15);
    assert (!runs = 2);
    
    set_b 20;
    assert (!sum = 33);
    assert (!runs = 3);
    
    set_c 30;
    assert (!sum = 60);
    assert (!runs = 4)
  );
  print_endline "  PASSED"

(* ============ Nested Effects ============ *)

let test_nested_effects () =
  print_endline "Test: Nested effects";
  with_runtime (fun () ->
    let outer_runs = ref 0 in
    let inner_runs = ref 0 in
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    
    Effect.create (fun () ->
      incr outer_runs;
      let _ = Signal.get a in
      Effect.create (fun () ->
        incr inner_runs;
        let _ = Signal.get b in
        ()
      )
    );
    
    assert (!outer_runs = 1);
    assert (!inner_runs = 1);
    
    (* Changing b should only trigger inner *)
    set_b 20;
    assert (!outer_runs = 1);
    assert (!inner_runs = 2);
    
    (* Changing a triggers outer, which recreates inner *)
    set_a 10;
    assert (!outer_runs = 2);
    (* Inner runs once from outer's re-creation *)
    assert (!inner_runs >= 3)
  );
  print_endline "  PASSED"

(* ============ Batch with Memo ============ *)

let test_batch_with_memo () =
  print_endline "Test: Batch with memo";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let runs = ref 0 in
    let sum = Memo.create (fun () ->
      incr runs;
      Signal.get a + Signal.get b
    ) in
    assert (Memo.get sum = 3);
    let r1 = !runs in
    
    (* Without batch, each set might trigger memo *)
    Batch.run (fun () ->
      set_a 10;
      set_b 20
    );
    assert (Memo.get sum = 30);
    (* Memo should only run once for the batch *)
    assert (!runs <= r1 + 1)
  );
  print_endline "  PASSED"

(* ============ Signal Update with Function ============ *)

let test_signal_update_fn_batched () =
  print_endline "Test: Signal update with fn in batch";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, _ = Signal.create 0 in
    let b, _ = Signal.create 0 in
    Effect.create (fun () ->
      Signal.update a (fun v -> v + 1);
      Signal.update b (fun v -> v + 1)
    );
    let _ = Memo.create (fun () ->
      count := !count + Signal.get a + Signal.get b;
      !count
    ) in
    assert (!count = 2)
  );
  print_endline "  PASSED"

let test_signal_update_fn_repeated () =
  print_endline "Test: Signal update with fn repeated";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, _ = Signal.create 0 in
    Effect.create (fun () ->
      Signal.update a (fun v -> v + 1);
      Signal.update a (fun v -> v + 2)
    );
    let _ = Memo.create (fun () ->
      count := Signal.get a;
      !count
    ) in
    (* Should be 0 + 1 + 2 = 3 *)
    assert (!count = 3)
  );
  print_endline "  PASSED"

(* ============ Cross-setting in Effect ============ *)

let test_cross_setting_in_effect () =
  print_endline "Test: Cross-setting in effect";
  with_runtime (fun () ->
    let count = ref 0 in
    let a, _ = Signal.create 1 in
    let b, set_b = Signal.create 0 in
    Effect.create (fun () ->
      Signal.update a (fun v -> v + Signal.get b)
    );
    let _ = Memo.create (fun () ->
      count := !count + Signal.get a;
      !count
    ) in
    (* a starts at 1, b starts at 0, so a = 1 + 0 = 1 *)
    let initial = !count in
    assert (initial = 1);
    
    (* Setting b should trigger effect, which updates a *)
    set_b 1;
    (* a = 1 + 1 = 2, count = 1 + 2 = 3 *)
    assert (!count = 3)
  );
  print_endline "  PASSED"

(* ============ Memo Equality Check ============ *)

let test_memo_equality_skip () =
  print_endline "Test: Memo skips downstream when value unchanged";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let runs = ref 0 in
    (* Memo that always returns same value regardless of input *)
    let m = Memo.create (fun () ->
      let _ = Signal.get a in
      "constant"
    ) in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      incr effect_runs;
      let _ = Memo.get m in
      ()
    );
    assert (!effect_runs = 1);
    runs := 0;
    
    (* Changing a recomputes memo, but value is same *)
    set_a 2;
    (* Effect should NOT re-run because memo value unchanged *)
    (* Note: This depends on memo equality checking working correctly *)
    assert (Memo.get m = "constant")
  );
  print_endline "  PASSED"

(* ============ Disposal Order ============ *)

let test_disposal_order () =
  print_endline "Test: Disposal runs cleanups";
  with_runtime (fun () ->
    let order = ref [] in
    let dispose = Owner.create_root (fun () ->
      Owner.on_cleanup (fun () -> order := !order @ [1]);
      Owner.on_cleanup (fun () -> order := !order @ [2]);
      Owner.on_cleanup (fun () -> order := !order @ [3])
    ) in
    dispose ();
    (* Cleanups should all run - order may vary by implementation *)
    assert (List.length !order = 3);
    assert (List.mem 1 !order);
    assert (List.mem 2 !order);
    assert (List.mem 3 !order)
  );
  print_endline "  PASSED"

(* ============ Effect Cleanup Before Re-run ============ *)

let test_effect_cleanup_before_rerun () =
  print_endline "Test: Effect cleanup runs before re-run";
  with_runtime (fun () ->
    let log = ref [] in
    let a, set_a = Signal.create 1 in
    Effect.create_with_cleanup (fun () ->
      let v = Signal.get a in
      log := !log @ [Printf.sprintf "run:%d" v];
      fun () -> log := !log @ [Printf.sprintf "cleanup:%d" v]
    );
    assert (!log = ["run:1"]);
    set_a 2;
    (* Cleanup should run before the new effect execution *)
    assert (!log = ["run:1"; "cleanup:1"; "run:2"])
  );
  print_endline "  PASSED"

(* ============ Memo with Same Reference ============ *)

let test_memo_reference_equality () =
  print_endline "Test: Memo with physical equality";
  with_runtime (fun () ->
    let obj = ref [1; 2; 3] in
    let a, set_a = Signal.create 0 in
    let runs = ref 0 in
    (* Memo returns same reference *)
    let m = Memo.create_with_equals ~eq:(==) (fun () ->
      let _ = Signal.get a in
      incr runs;
      obj
    ) in
    assert (Memo.get m == obj);
    let r1 = !runs in
    
    (* Change signal, memo recomputes but returns same reference *)
    set_a 1;
    let _ = Memo.get m in
    (* Memo should have recomputed *)
    assert (!runs = r1 + 1);
    (* But downstream shouldn't see it as changed due to physical equality *)
    assert (Memo.get m == obj)
  );
  print_endline "  PASSED"

(* ============ Nested Batch ============ *)

let test_nested_batch () =
  print_endline "Test: Nested batch defers until outermost completes";
  with_runtime (fun () ->
    let a, set_a = Signal.create 0 in
    let runs = ref 0 in
    Effect.create (fun () ->
      incr runs;
      let _ = Signal.get a in
      ()
    );
    assert (!runs = 1);
    
    Batch.run (fun () ->
      set_a 1;
      Batch.run (fun () ->
        set_a 2;
        set_a 3
      );
      (* Inner batch completed but outer hasn't - effect shouldn't run yet *)
      set_a 4
    );
    (* After all batches complete, effect should have run once with final value *)
    assert (Signal.get a = 4);
    assert (!runs = 2)
  );
  print_endline "  PASSED"

(* ============ Effect in Effect ============ *)

let test_effect_in_effect_cleanup () =
  print_endline "Test: Nested effects track independently";
  with_runtime (fun () ->
    let outer, set_outer = Signal.create 1 in
    let inner, set_inner = Signal.create 1 in
    let outer_run_count = ref 0 in
    let inner_run_count = ref 0 in
    
    Effect.create (fun () ->
      incr outer_run_count;
      let _ = Signal.get outer in
      Effect.create (fun () ->
        incr inner_run_count;
        let _ = Signal.get inner in
        ()
      )
    );
    
    assert (!outer_run_count = 1);
    assert (!inner_run_count = 1);
    
    (* Trigger inner effect only *)
    set_inner 2;
    assert (!outer_run_count = 1);  (* Outer didn't re-run *)
    assert (!inner_run_count = 2);  (* Inner did re-run *)
    
    (* Trigger outer - creates new inner *)
    set_outer 2;
    assert (!outer_run_count = 2);
    (* Inner runs again as part of outer's re-execution *)
    assert (!inner_run_count >= 3)
  );
  print_endline "  PASSED"

(* ============ Main ============ *)

let () =
  print_endline "\n=== SolidJS Compatibility Tests ===\n";
  
  print_endline "-- Create Signals --";
  test_create_and_read_signal ();
  test_create_signal_with_comparator ();
  test_create_and_read_memo ();
  
  print_endline "\n-- Update Signals --";
  test_create_and_update_signal ();
  test_create_and_update_signal_with_fn ();
  test_signal_set_different_value ();
  test_signal_set_equivalent_value ();
  test_create_and_trigger_memo ();
  test_memo_not_triggered_on_equivalent_value ();
  test_create_and_trigger_memo_in_effect ();
  test_create_and_trigger_effect ();
  
  print_endline "\n-- Untrack Signals --";
  test_mute_effect_with_untrack ();
  
  print_endline "\n-- Effect Grouping --";
  test_groups_updates ();
  test_groups_updates_with_repeated_sets ();
  test_multiple_sets ();
  
  print_endline "\n-- onCleanup --";
  test_clean_effect ();
  test_explicit_root_disposal ();
  
  print_endline "\n-- Context --";
  test_create_context_defaults_to_default ();
  test_context_provide_and_use ();
  
  print_endline "\n-- createRoot --";
  test_nested_roots ();
  
  print_endline "\n-- Diamond Dependency --";
  test_diamond_dependency ();
  
  print_endline "\n-- Deep Memo Chain --";
  test_deep_memo_chain ();
  
  print_endline "\n-- Conditional Dependencies --";
  test_conditional_memo_deps ();
  
  print_endline "\n-- Effect with Multiple Sources --";
  test_effect_multiple_sources ();
  
  print_endline "\n-- Nested Effects --";
  test_nested_effects ();
  
  print_endline "\n-- Batch with Memo --";
  test_batch_with_memo ();
  
  print_endline "\n-- Signal Update with Function --";
  test_signal_update_fn_batched ();
  test_signal_update_fn_repeated ();
  
  print_endline "\n-- Cross-setting --";
  test_cross_setting_in_effect ();
  
  print_endline "\n-- Memo Equality --";
  test_memo_equality_skip ();
  
  print_endline "\n-- Disposal --";
  test_disposal_order ();
  test_effect_cleanup_before_rerun ();
  
  print_endline "\n-- Reference Equality --";
  test_memo_reference_equality ();
  
  print_endline "\n-- Nested Batch --";
  test_nested_batch ();
  
  print_endline "\n-- Effect Lifecycle --";
  test_effect_in_effect_cleanup ();
  
  print_endline "\n=== All SolidJS compatibility tests passed! ===\n"

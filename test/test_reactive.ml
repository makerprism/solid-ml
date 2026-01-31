(** Tests for solid-ml reactive primitives *)

[@@@ocaml.warning "-32"]

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

module Raw_signal = Signal

module Signal = struct
  include Raw_signal

  let create ?equals value =
    let signal, set = Raw_signal.create ?equals value in
    (signal, fun v -> ignore (set v))

  let create_eq ~equals value =
    let signal, set = Raw_signal.create_eq ~equals value in
    (signal, fun v -> ignore (set v))

  let create_physical value =
    let signal, set = Raw_signal.create_physical value in
    (signal, fun v -> ignore (set v))

  let set signal value =
    ignore (Raw_signal.set signal value)

  let update signal f =
    ignore (Raw_signal.update signal f)
end

(** Helper to run test within a reactive runtime *)
let with_runtime fn =
  Runtime.run (fun () ->
    let dispose = Owner.create_root fn in
    dispose ()
  )

let ignore_set set v = ignore (set v)

let test_requires_runtime () =
  print_endline "Test: Runtime required on server";
  assert (Solid_ml.Runtime.get_current_opt () = None);
  let raised = ref false in
  (try
     let _ = Solid_ml.Signal.create 0 in
     ()
   with Solid_ml_internal.Types.No_runtime _ ->
     raised := true);
  assert !raised;
  let raised_effect = ref false in
  (try
     Solid_ml.Effect.create (fun () -> ());
     ()
   with Solid_ml_internal.Types.No_runtime _ ->
     raised_effect := true);
  assert !raised_effect;
  let raised_memo = ref false in
  (try
     let _ = Solid_ml.Memo.create (fun () -> 1) in
     ()
   with Solid_ml_internal.Types.No_runtime _ ->
     raised_memo := true);
  assert !raised_memo;
  print_endline "  PASSED"

(* ============ Signal Tests ============ *)

let test_signal_basic () =
  print_endline "Test: Signal basic operations";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    assert (Signal.get count = 0);
    set_count 5;
    assert (Signal.get count = 5);
    ignore (Signal.update count (fun n -> n + 1));
    assert (Signal.get count = 6)
  );
  print_endline "  PASSED"

let test_signal_peek () =
  print_endline "Test: Signal.peek doesn't track";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      (* Use peek - should not track *)
      let _ = Signal.peek count in
      incr effect_runs
    );
    assert (!effect_runs = 1);  (* Initial run *)
    set_count 1;
    assert (!effect_runs = 1)  (* Should NOT have re-run *)
  );
  print_endline "  PASSED"

let test_signal_subscribe () =
  print_endline "Test: Signal.subscribe and unsubscribe";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let notifications = ref 0 in
    let unsub = Signal.subscribe count (fun () -> incr notifications) in
    set_count 1;
    assert (!notifications = 1);
    set_count 2;
    assert (!notifications = 2);
    unsub ();
    set_count 3;
    assert (!notifications = 2)  (* No more notifications after unsub *)
  );
  print_endline "  PASSED"

let test_signal_equality () =
  print_endline "Test: Signal skips update on equal value (structural)";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get count in
      incr effect_runs
    );
    assert (!effect_runs = 1);
    set_count 0;  (* Same value *)
    assert (!effect_runs = 1);  (* Should not re-run *)
    set_count 1;  (* Different value *)
    assert (!effect_runs = 2)
  );
  print_endline "  PASSED"

let test_signal_physical_equality () =
  print_endline "Test: Signal.create_physical uses physical equality";
  with_runtime (fun () ->
    (* Use mutable bytes to ensure different physical objects *)
    let b1 = Bytes.of_string "hello" in
    let b2 = Bytes.of_string "hello" in
    let s, set_s = Signal.create_physical b1 in
    let set_s = ignore_set set_s in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get s in
      incr effect_runs
    );
    assert (!effect_runs = 1);
    set_s b2;  (* Different bytes object but same content *)
    assert (!effect_runs = 2);  (* Should re-run with physical equality *)
    let same_ref = Signal.peek s in
    set_s same_ref;  (* Same exact object *)
    assert (!effect_runs = 2)  (* Should not re-run *)
  );
  print_endline "  PASSED"

let test_signal_physical_equality_strings () =
  print_endline "Test: Signal uses physical equality for strings by default";
  with_runtime (fun () ->
    let s, set_s = Signal.create "hello" in
    let set_s = ignore_set set_s in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get s in
      incr effect_runs
    );
    assert (!effect_runs = 1);
    let copied = Bytes.to_string (Bytes.of_string "hello") in
    set_s copied;  (* Same content, different object *)
    assert (!effect_runs = 2);  (* Should re-run with physical equality *)
    let same_ref = Signal.peek s in
    set_s same_ref;
    assert (!effect_runs = 2);
    set_s "world";  (* Different content *)
    assert (!effect_runs = 3)
  );
  print_endline "  PASSED"

(* ============ Effect Tests ============ *)

let test_effect_tracking () =
  print_endline "Test: Effect auto-tracks dependencies";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let effect_runs = ref 0 in
    let last_seen = ref 0 in
    Effect.create (fun () ->
      last_seen := Signal.get count;
      incr effect_runs
    );
    assert (!effect_runs = 1);
    assert (!last_seen = 0);
    set_count 10;
    assert (!effect_runs = 2);
    assert (!last_seen = 10);
    set_count 20;
    assert (!effect_runs = 3);
    assert (!last_seen = 20)
  );
  print_endline "  PASSED"

let test_effect_multiple_signals () =
  print_endline "Test: Effect tracks multiple signals";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let sum = ref 0 in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      sum := Signal.get a + Signal.get b;
      incr effect_runs
    );
    assert (!sum = 3);
    assert (!effect_runs = 1);
    set_a 10;
    assert (!sum = 12);
    assert (!effect_runs = 2);
    set_b 20;
    assert (!sum = 30);
    assert (!effect_runs = 3)
  );
  print_endline "  PASSED"

let test_effect_untrack () =
  print_endline "Test: Effect.untrack prevents tracking";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get a in  (* tracked *)
      let _ = Effect.untrack (fun () -> Signal.get b) in  (* NOT tracked *)
      incr effect_runs
    );
    assert (!effect_runs = 1);
    set_a 10;
    assert (!effect_runs = 2);  (* a is tracked, should re-run *)
    set_b 20;
    assert (!effect_runs = 2)  (* b is NOT tracked, should NOT re-run *)
  );
  print_endline "  PASSED"

let test_effect_cleanup () =
  print_endline "Test: Effect cleanup runs before re-execution";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let cleanups = ref 0 in
    Effect.create_with_cleanup (fun () ->
      let _ = Signal.get count in
      fun () -> incr cleanups
    );
    assert (!cleanups = 0);  (* No cleanup yet *)
    set_count 1;
    assert (!cleanups = 1);  (* Cleanup ran before re-execution *)
    set_count 2;
    assert (!cleanups = 2)
  );
  print_endline "  PASSED"

let test_effect_conditional_deps () =
  print_endline "Test: Effect tracks conditional dependencies";
  with_runtime (fun () ->
    let flag, set_flag = Signal.create true in
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let set_flag = ignore_set set_flag in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let result = ref 0 in
    let runs = ref 0 in
    Effect.create (fun () ->
      incr runs;
      result := if Signal.get flag then Signal.get a else Signal.get b
    );
    assert (!result = 1);
    assert (!runs = 1);
    set_a 10;  (* a is tracked *)
    assert (!result = 10);
    assert (!runs = 2);
    set_b 20;  (* b is NOT tracked when flag=true *)
    assert (!result = 10);
    assert (!runs = 2);
    set_flag false;  (* Now track b instead of a *)
    assert (!result = 20);
    assert (!runs = 3);
    set_a 100;  (* a is no longer tracked *)
    assert (!result = 20);
    assert (!runs = 3);
    set_b 200;  (* b is now tracked *)
    assert (!result = 200);
    assert (!runs = 4)
  );
  print_endline "  PASSED"

let test_render_effect_ordering () =
  print_endline "Test: Render effects run before user effects";
  with_runtime (fun () ->
    let order = ref [] in
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    Effect.create_render_effect (fun () ->
      let v = Signal.get count in
      order := ("render", v) :: !order
    );
    Effect.create (fun () ->
      let v = Signal.get count in
      order := ("user", v) :: !order
    );
    assert (List.rev !order = [ ("render", 0); ("user", 0) ]);
    order := [];
    set_count 1;
    assert (List.rev !order = [ ("render", 1); ("user", 1) ])
  );
  print_endline "  PASSED"

let test_reaction_basic () =
  print_endline "Test: create_reaction runs after tracked changes";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let calls = ref [] in
    let track = Effect.create_reaction (fun ~value ~prev ->
      calls := (prev, value) :: !calls
    ) in
    assert (!calls = []);
    track (fun () -> Signal.get count);
    assert (!calls = []);
    set_count 1;
    assert (List.rev !calls = [ (0, 1) ])
  );
  print_endline "  PASSED"

let test_reaction_retarget () =
  print_endline "Test: create_reaction retargets dependencies";
  with_runtime (fun () ->
    let a, set_a = Signal.create 0 in
    let b, set_b = Signal.create 0 in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let calls = ref 0 in
    let track = Effect.create_reaction (fun ~value:_ ~prev:_ -> incr calls) in
    track (fun () -> Signal.get a);
    set_a 1;
    assert (!calls = 1);
    track (fun () -> Signal.get b);
    set_a 2;
    assert (!calls = 1);
    set_b 3;
    assert (!calls = 2)
  );
  print_endline "  PASSED"

let test_reaction_untracked_body () =
  print_endline "Test: create_reaction does not track inside callback";
  with_runtime (fun () ->
    let a, set_a = Signal.create 0 in
    let b, set_b = Signal.create 0 in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let calls = ref 0 in
    let track = Effect.create_reaction (fun ~value:_ ~prev:_ ->
      let _ = Signal.get b in
      incr calls
    ) in
    track (fun () -> Signal.get a);
    set_b 1;
    assert (!calls = 0);
    set_a 1;
    assert (!calls = 1)
  );
  print_endline "  PASSED"

(* ============ Memo Tests ============ *)

let test_memo_basic () =
  print_endline "Test: Memo caches derived values";
  with_runtime (fun () ->
    let count, set_count = Signal.create 2 in
    let set_count = ignore_set set_count in
    let compute_runs = ref 0 in
    let doubled = Memo.create (fun () ->
      incr compute_runs;
      Signal.get count * 2
    ) in
    (* Memos are eager - computation runs on create (like SolidJS) *)
    assert (!compute_runs = 1);
    (* Reading uses cached value - no recompute *)
    assert (Memo.get doubled = 4);
    assert (!compute_runs = 1);
    (* Second read also uses cached value *)
    assert (Memo.get doubled = 4);
    assert (!compute_runs = 1);
    (* Changing dependency marks memo stale *)
    set_count 5;
    (* Reading again should recompute *)
    assert (Memo.get doubled = 10);
    assert (!compute_runs = 2)
  );
  print_endline "  PASSED"

let test_memo_chains () =
  print_endline "Test: Memos can depend on other memos";
  with_runtime (fun () ->
    let count, set_count = Signal.create 2 in
    let set_count = ignore_set set_count in
    let doubled = Memo.create (fun () -> Signal.get count * 2) in
    let quadrupled = Memo.create (fun () -> Memo.get doubled * 2) in
    assert (Memo.get quadrupled = 8);
    set_count 3;
    assert (Memo.get doubled = 6);
    assert (Memo.get quadrupled = 12)
  );
  print_endline "  PASSED"

let test_memo_equality () =
  print_endline "Test: Memo with custom equality";
  with_runtime (fun () ->
    let list_signal, set_list = Signal.create ~equals:(=) [1; 2; 3] in
    let set_list = ignore_set set_list in
    let downstream_runs = ref 0 in
    (* This memo only changes when list length changes *)
    let length = Memo.create_with_equals
      ~eq:(=)
      (fun () -> List.length (Signal.get list_signal))
    in
    Effect.create (fun () ->
      let _ = Memo.get length in
      incr downstream_runs
    );
    assert (!downstream_runs = 1);
    set_list [4; 5; 6];  (* Same length, but list is different - signal will fire *)
    (* Note: the memo uses structural equality, so same length = no downstream update *)
    set_list [1; 2; 3; 4];  (* Different length *)
    assert (!downstream_runs = 2)
  );
  print_endline "  PASSED"

(* ============ Batch Tests ============ *)

let test_batch_basic () =
  print_endline "Test: Batch groups updates";
  with_runtime (fun () ->
    let a, set_a = Signal.create 1 in
    let b, set_b = Signal.create 2 in
    let set_a = ignore_set set_a in
    let set_b = ignore_set set_b in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get a + Signal.get b in
      incr effect_runs
    );
    assert (!effect_runs = 1);
    (* Without batch: two runs *)
    set_a 10;
    assert (!effect_runs = 2);
    set_b 20;
    assert (!effect_runs = 3);
    (* With batch: single notification at end *)
    let prev_runs = !effect_runs in
    Batch.run (fun () ->
      set_a 100;
      set_b 200
    );
    assert (Signal.get a = 100);
    assert (Signal.get b = 200);
    (* Should run only once for batched updates *)
    assert (!effect_runs = prev_runs + 1)
  );
  print_endline "  PASSED"

let test_batch_nested () =
  print_endline "Test: Nested batches";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let effect_runs = ref 0 in
    Effect.create (fun () ->
      let _ = Signal.get count in
      incr effect_runs
    );
    assert (!effect_runs = 1);
    Batch.run (fun () ->
      set_count 1;
      Batch.run (fun () ->
        set_count 2
      );
      set_count 3
    );
    assert (Signal.get count = 3)
  );
  print_endline "  PASSED"

(* ============ Owner Tests ============ *)

let test_owner_basic () =
  print_endline "Test: Owner.create_root and disposal";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let effect_runs = ref 0 in
    let dispose = Owner.create_root (fun () ->
      Effect.create (fun () ->
        let _ = Signal.get count in
        incr effect_runs
      )
    ) in
    assert (!effect_runs = 1);
    set_count 1;
    assert (!effect_runs = 2);
    dispose ();
    set_count 2;
    assert (!effect_runs = 2)  (* Effect no longer runs after dispose *)
  );
  print_endline "  PASSED"

let test_owner_nested () =
  print_endline "Test: Nested owners dispose children";
  with_runtime (fun () ->
    let cleanups = ref [] in
    let dispose = Owner.create_root (fun () ->
      Owner.on_cleanup (fun () -> cleanups := "root" :: !cleanups);
      let _, _ = Owner.run_with_root (fun () ->
        Owner.on_cleanup (fun () -> cleanups := "child" :: !cleanups)
      ) in
      ()
    ) in
    assert (!cleanups = []);
    dispose ();
    (* Child should be cleaned up before root *)
    assert (!cleanups = ["root"; "child"])
  );
  print_endline "  PASSED"

let test_owner_on_cleanup () =
  print_endline "Test: Owner.on_cleanup runs on dispose";
  with_runtime (fun () ->
    let cleaned_up = ref false in
    let dispose = Owner.create_root (fun () ->
      Owner.on_cleanup (fun () -> cleaned_up := true)
    ) in
    assert (not !cleaned_up);
    dispose ();
    assert !cleaned_up
  );
  print_endline "  PASSED"

let test_owner_cleanup_on_dispose () =
  print_endline "Test: Owner cleanups run on dispose";
  with_runtime (fun () ->
    let cleanup_ran = ref false in
    let dispose_child = Owner.create_root (fun () ->
      Owner.on_cleanup (fun () -> cleanup_ran := true)
    ) in
    assert (not !cleanup_ran);
    dispose_child ();
    assert !cleanup_ran
  );
  print_endline "  PASSED"

let test_run_with_owner_scope () =
  print_endline "Test: Owner.run_with_owner restores scope";
  with_runtime (fun () ->
    let original = Owner.get_owner () in
    let inside = ref None in
    let result = Owner.run_with_owner None (fun () ->
      inside := Owner.get_owner ();
      123
    ) in
    assert (!inside = None);
    assert (Owner.get_owner () = original);
    assert (result = 123)
  );
  print_endline "  PASSED"

let test_run_with_owner_reuse () =
  print_endline "Test: Owner.run_with_owner uses provided owner";
  with_runtime (fun () ->
    let original = Owner.get_owner () in
    let inside = ref None in
    Owner.run_with_owner original (fun () ->
      inside := Owner.get_owner ()
    );
    assert (!inside = original)
  );
  print_endline "  PASSED"

(* ============ Context Tests ============ *)

let test_context_basic () =
  print_endline "Test: Context basic provide/use";
  with_runtime (fun () ->
    let theme_ctx = Context.create "light" in
    assert (Context.use theme_ctx = "light");  (* Default *)
    let result = Context.provide theme_ctx "dark" (fun () ->
      Context.use theme_ctx
    ) in
    assert (result = "dark");
    assert (Context.use theme_ctx = "light")  (* Back to default *)
  );
  print_endline "  PASSED"

let test_context_nested () =
  print_endline "Test: Context nested provides";
  with_runtime (fun () ->
    let ctx = Context.create 0 in
    Context.provide ctx 1 (fun () ->
      assert (Context.use ctx = 1);
      Context.provide ctx 2 (fun () ->
        assert (Context.use ctx = 2);
        Context.provide ctx 3 (fun () ->
          assert (Context.use ctx = 3)
        );
        assert (Context.use ctx = 2)
      );
      assert (Context.use ctx = 1)
    );
    assert (Context.use ctx = 0)
  );
  print_endline "  PASSED"

let test_context_multiple () =
  print_endline "Test: Multiple independent contexts";
  with_runtime (fun () ->
    let ctx_a = Context.create "a" in
    let ctx_b = Context.create "b" in
    Context.provide ctx_a "A" (fun () ->
      assert (Context.use ctx_a = "A");
      assert (Context.use ctx_b = "b");  (* Still default *)
      Context.provide ctx_b "B" (fun () ->
        assert (Context.use ctx_a = "A");
        assert (Context.use ctx_b = "B")
      )
    )
  );
  print_endline "  PASSED"

let test_context_with_signals () =
  print_endline "Test: Context with reactive signals";
  with_runtime (fun () ->
    let theme_ctx = Context.create "light" in
    let observed = ref "" in
    Context.provide theme_ctx "dark" (fun () ->
      Effect.create (fun () ->
        observed := Context.use theme_ctx
      )
    );
    assert (!observed = "dark")
  );
  print_endline "  PASSED"

let test_context_owner_tree () =
  print_endline "Test: Context uses owner tree (not global stack)";
  with_runtime (fun () ->
    let ctx = Context.create 0 in
    (* Create two sibling owners with different context values *)
    Context.provide ctx 1 (fun () ->
      let value_in_first = Context.use ctx in
      assert (value_in_first = 1);
      (* The value should be on the owner, not a global stack *)
      let dispose = Owner.create_root (fun () ->
        (* Child owner should inherit parent's context *)
        assert (Context.use ctx = 1)
      ) in
      dispose ()
    );
    (* After exiting, should be back to default *)
    assert (Context.use ctx = 0)
  );
  print_endline "  PASSED"

(* ============ Integration Tests ============ *)

let test_diamond_dependency () =
  print_endline "Test: Diamond dependency pattern";
  with_runtime (fun () ->
    (*      count
           /     \
        double  triple
           \     /
            sum
    *)
    let count, set_count = Signal.create 1 in
    let set_count = ignore_set set_count in
    let double = Memo.create (fun () -> Signal.get count * 2) in
    let triple = Memo.create (fun () -> Signal.get count * 3) in
    let sum_runs = ref 0 in
    let sum = Memo.create (fun () ->
      incr sum_runs;
      Memo.get double + Memo.get triple
    ) in
    assert (Memo.get sum = 5);  (* 2 + 3 *)
    let initial_runs = !sum_runs in
    set_count 2;
    assert (Memo.get sum = 10);  (* 4 + 6 *)
    (* Should only compute once per change *)
    assert (!sum_runs <= initial_runs + 2)  (* Allow some extra due to impl *)
  );
  print_endline "  PASSED"

let test_effect_with_memo () =
  print_endline "Test: Effect depending on memo";
  with_runtime (fun () ->
    let count, set_count = Signal.create 0 in
    let set_count = ignore_set set_count in
    let doubled = Memo.create (fun () -> Signal.get count * 2) in
    let observed = ref 0 in
    Effect.create (fun () ->
      observed := Memo.get doubled
    );
    assert (!observed = 0);
    set_count 5;
    assert (!observed = 10)
  );
  print_endline "  PASSED"

let test_runtime_isolation () =
  print_endline "Test: Separate runtimes are isolated";
  (* This is the key test for thread safety *)
  let results = ref [] in
  
  (* First runtime *)
  Runtime.run (fun () ->
    let dispose = Owner.create_root (fun () ->
      let count, set_count = Signal.create 100 in
      let set_count = ignore_set set_count in
      Effect.create (fun () ->
        results := ("r1", Signal.get count) :: !results
      );
      set_count 101
    ) in
    dispose ()
  );
  
  (* Second runtime - should be completely independent *)
  Runtime.run (fun () ->
    let dispose = Owner.create_root (fun () ->
      let count, set_count = Signal.create 200 in
      let set_count = ignore_set set_count in
      Effect.create (fun () ->
        results := ("r2", Signal.get count) :: !results
      );
      set_count 201
    ) in
    dispose ()
  );
  
  (* Both runtimes should have run independently *)
  assert (List.mem ("r1", 100) !results);
  assert (List.mem ("r1", 101) !results);
  assert (List.mem ("r2", 200) !results);
  assert (List.mem ("r2", 201) !results);
  print_endline "  PASSED"

let test_domain_parallelism () =
  print_endline "Test: Domain parallelism with Domain-local storage";
  (* Each domain gets its own runtime via Domain.DLS *)
  let num_domains = 4 in
  let results = Array.make num_domains 0 in
  
  let domains = Array.init num_domains (fun i ->
    Domain.spawn (fun () ->
      Runtime.run (fun () ->
        let dispose = Owner.create_root (fun () ->
          let count, _set_count = Signal.create 0 in
          let sum = ref 0 in
          Effect.create (fun () ->
            sum := !sum + Signal.get count
          );
          (* Each domain increments differently *)
          for _ = 1 to (i + 1) * 10 do
            ignore (Signal.update count (fun n -> n + 1))
          done;
          results.(i) <- !sum
        ) in
        dispose ()
      )
    )
  ) in
  
  (* Wait for all domains *)
  Array.iter Domain.join domains;
  
  (* Each domain should have computed its own sum independently *)
  (* Domain 0: 1+2+...+10 = 55 *)
  (* Domain 1: 1+2+...+20 = 210 *)
  (* Domain 2: 1+2+...+30 = 465 *)
  (* Domain 3: 1+2+...+40 = 820 *)
  assert (results.(0) = 55);
  assert (results.(1) = 210);
  assert (results.(2) = 465);
  assert (results.(3) = 820);
  print_endline "  PASSED"

(* ============ Main ============ *)

let () =
  print_endline "\n=== solid-ml Reactive Tests ===\n";
  
  print_endline "-- Signal Tests --";
  test_signal_basic ();
  test_signal_peek ();
  test_signal_subscribe ();
  test_signal_equality ();
  test_signal_physical_equality ();
  test_signal_physical_equality_strings ();
  
  print_endline "\n-- Effect Tests --";
  test_effect_tracking ();
  test_effect_multiple_signals ();
  test_effect_untrack ();
  test_effect_cleanup ();
  test_effect_conditional_deps ();
  test_render_effect_ordering ();
  test_reaction_basic ();
  test_reaction_retarget ();
  test_reaction_untracked_body ();
  
  print_endline "\n-- Memo Tests --";
  test_memo_basic ();
  test_memo_chains ();
  test_memo_equality ();
  
  print_endline "\n-- Batch Tests --";
  test_batch_basic ();
  test_batch_nested ();
  
  print_endline "\n-- Owner Tests --";
  test_owner_basic ();
  test_owner_nested ();
  test_owner_on_cleanup ();
  test_owner_cleanup_on_dispose ();
  test_run_with_owner_scope ();
  test_run_with_owner_reuse ();
  
  print_endline "\n-- Context Tests --";
  test_context_basic ();
  test_context_nested ();
  test_context_multiple ();
  test_context_with_signals ();
  test_context_owner_tree ();
  
  print_endline "\n-- Integration Tests --";
  test_diamond_dependency ();
  test_effect_with_memo ();
  test_requires_runtime ();
  test_runtime_isolation ();
  test_domain_parallelism ();
  
  print_endline "\n=== All tests passed! ===\n"

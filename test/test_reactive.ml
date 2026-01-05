(** Tests for solid-ml reactive primitives *)

open Solid_ml

let test_signal_basic () =
  print_endline "Test: Signal basic operations";
  let count, set_count = Signal.create 0 in
  assert (Signal.get count = 0);
  set_count 5;
  assert (Signal.get count = 5);
  Signal.update count (fun n -> n + 1);
  assert (Signal.get count = 6);
  print_endline "  PASSED"

let test_signal_peek () =
  print_endline "Test: Signal.peek doesn't track";
  let count, set_count = Signal.create 0 in
  let effect_runs = ref 0 in
  Effect.create (fun () ->
    (* Use peek - should not track *)
    let _ = Signal.peek count in
    incr effect_runs
  );
  assert (!effect_runs = 1);  (* Initial run *)
  set_count 1;
  assert (!effect_runs = 1);  (* Should NOT have re-run *)
  print_endline "  PASSED"

let test_effect_tracking () =
  print_endline "Test: Effect auto-tracks dependencies";
  let count, set_count = Signal.create 0 in
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
  assert (!last_seen = 20);
  print_endline "  PASSED"

let test_effect_multiple_signals () =
  print_endline "Test: Effect tracks multiple signals";
  let a, set_a = Signal.create 1 in
  let b, set_b = Signal.create 2 in
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
  assert (!effect_runs = 3);
  print_endline "  PASSED"

let test_effect_untrack () =
  print_endline "Test: Effect.untrack prevents tracking";
  let a, set_a = Signal.create 1 in
  let b, set_b = Signal.create 2 in
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
  assert (!effect_runs = 2);  (* b is NOT tracked, should NOT re-run *)
  print_endline "  PASSED"

let test_effect_cleanup () =
  print_endline "Test: Effect cleanup runs before re-execution";
  let count, set_count = Signal.create 0 in
  let cleanups = ref 0 in
  Effect.create_with_cleanup (fun () ->
    let _ = Signal.get count in
    fun () -> incr cleanups
  );
  assert (!cleanups = 0);  (* No cleanup yet *)
  set_count 1;
  assert (!cleanups = 1);  (* Cleanup ran before re-execution *)
  set_count 2;
  assert (!cleanups = 2);
  print_endline "  PASSED"

let test_memo_basic () =
  print_endline "Test: Memo caches derived values";
  let count, set_count = Signal.create 2 in
  let compute_runs = ref 0 in
  let doubled = Memo.create (fun () ->
    incr compute_runs;
    Signal.get count * 2
  ) in
  (* Memo runs fn twice during creation: once for value, once for tracking *)
  let initial_runs = !compute_runs in
  assert (Signal.get doubled = 4);
  (* Reading should not recompute *)
  assert (!compute_runs = initial_runs);
  assert (Signal.get doubled = 4);
  assert (!compute_runs = initial_runs);
  (* Changing dependency should recompute once *)
  set_count 5;
  assert (!compute_runs = initial_runs + 1);
  assert (Signal.get doubled = 10);
  print_endline "  PASSED"

let test_memo_chains () =
  print_endline "Test: Memos can depend on other memos";
  let count, set_count = Signal.create 2 in
  let doubled = Memo.create (fun () -> Signal.get count * 2) in
  let quadrupled = Memo.create (fun () -> Signal.get doubled * 2) in
  assert (Signal.get quadrupled = 8);
  set_count 3;
  assert (Signal.get doubled = 6);
  assert (Signal.get quadrupled = 12);
  print_endline "  PASSED"

let () =
  print_endline "\n=== solid-ml Reactive Tests ===\n";
  test_signal_basic ();
  test_signal_peek ();
  test_effect_tracking ();
  test_effect_multiple_signals ();
  test_effect_untrack ();
  test_effect_cleanup ();
  test_memo_basic ();
  test_memo_chains ();
  print_endline "\n=== All tests passed! ===\n"

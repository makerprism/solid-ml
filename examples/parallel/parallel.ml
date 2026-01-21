(** Parallel execution example demonstrating OCaml 5 domain safety.

    This example shows:
    - Thread-safe runtime isolation via Domain-local storage
    - Parallel rendering across multiple domains
    - Each domain maintains independent reactive state

    Run with: dune exec examples/parallel/parallel.exe

    IMPORTANT: This demonstrates that solid-ml is safe for parallel execution,
    which is crucial for web servers handling concurrent requests.
*)

open Solid_ml
open Solid_ml_ssr

(** Simulate a component that uses signals and memos *)
let render_component ~id ~delay_ms () =
  (* Each domain has its own isolated runtime state *)
  let counter, _set_counter = Signal.Unsafe.create id in
  let squared = Memo.Unsafe.create (fun () ->
    let n = Signal.get counter in
    n * n
  ) in
  
  (* Simulate some work *)
  Unix.sleepf (float_of_int delay_ms /. 1000.0);
  
  Html.(
    div ~id:(Printf.sprintf "component-%d" id) ~children:[
      p ~children:[text (Printf.sprintf "Component %d" id)] ();
      p ~children:[
        text "Value: ";
        signal_text counter;
      ] ();
      p ~children:[
        text "Squared: ";
        (* For SSR, we read the memo value directly *)
        text (string_of_int (Memo.get squared));
      ] ();
    ] ()
  )

(** Sequential rendering (baseline) *)
let render_sequential n =
  print_endline "Sequential rendering...";
  let start = Unix.gettimeofday () in
  
  let results = Array.init n (fun i ->
    Render.to_string (fun () -> render_component ~id:i ~delay_ms:50 ())
  ) in
  
  let elapsed = Unix.gettimeofday () -. start in
  Printf.printf "Sequential: rendered %d components in %.3fs\n\n" n elapsed;
  results

(** Parallel rendering using OCaml 5 domains *)
let render_parallel n =
  print_endline "Parallel rendering...";
  let start = Unix.gettimeofday () in
  
  (* Spawn a domain for each component *)
  let domains = Array.init n (fun i ->
    Domain.spawn (fun () ->
      (* Each domain gets its own runtime via Domain-local storage *)
      Render.to_string (fun () -> render_component ~id:i ~delay_ms:50 ())
    )
  ) in
  
  (* Wait for all domains to complete *)
  let results = Array.map Domain.join domains in
  
  let elapsed = Unix.gettimeofday () -. start in
  Printf.printf "Parallel: rendered %d components in %.3fs\n\n" n elapsed;
  results

(** Demonstrate runtime isolation *)
let demonstrate_isolation () =
  print_endline "=== Runtime Isolation Demo ===\n";
  
  (* Spawn two domains that each create their own signals *)
  let domain1 = Domain.spawn (fun () ->
    Runtime.Unsafe.run (fun () ->
      let value, set_value = Signal.Unsafe.create "Domain 1 Value" in
      (* This signal is completely isolated to this domain/runtime *)
      Effect.Unsafe.create (fun () ->
        Printf.printf "[Domain 1] Signal value: %s\n" (Signal.get value)
      );
      set_value "Domain 1 Updated";
      Signal.get value
    )
  ) in
  
  let domain2 = Domain.spawn (fun () ->
    Runtime.Unsafe.run (fun () ->
      let value, set_value = Signal.Unsafe.create "Domain 2 Value" in
      (* Completely independent from Domain 1's signal *)
      Effect.Unsafe.create (fun () ->
        Printf.printf "[Domain 2] Signal value: %s\n" (Signal.get value)
      );
      set_value "Domain 2 Updated";
      Signal.get value
    )
  ) in
  
  let result1 = Domain.join domain1 in
  let result2 = Domain.join domain2 in
  
  Printf.printf "\nFinal values:\n";
  Printf.printf "  Domain 1: %s\n" result1;
  Printf.printf "  Domain 2: %s\n" result2;
  print_endline ""

(** Main entry point *)
let () =
  demonstrate_isolation ();
  
  print_endline "=== Rendering Performance Comparison ===\n";
  
  let n = 8 in
  
  let seq_results = render_sequential n in
  let _par_results = render_parallel n in
  
  (* Note: Results won't match exactly because hydration keys are assigned
     per-runtime and parallel execution may interleave differently.
     The content is the same, just the hk:N markers may differ. *)
  Printf.printf "Note: Hydration keys may differ between sequential and parallel\n";
  Printf.printf "(This is expected - each runtime has its own hydration counter)\n\n";
  
  (* Show sample output *)
  print_endline "Sample rendered HTML (component 0):";
  print_endline seq_results.(0);
  
  print_endline "\n=== Parallel execution demo completed! ==="

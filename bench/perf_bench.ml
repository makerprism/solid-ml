(** Performance benchmarks for solid-ml-server reactive core *)

open Printf

(* Basic benchmark utilities *)
let timeit name f =
  let start_time = Sys.time () in
  let result = f () in
  let end_time = Sys.time () in
  let duration = end_time -. start_time in
  printf "%s: %.4f seconds\n" name duration;
  flush_all ();
  result

let run_multiple_times name count f =
  let start_time = Sys.time () in
  for i = 1 to count do
    if i mod 1000 = 0 then
      printf "\rProgress: %d/%d" i count;
    f ()
  done;
  let end_time = Sys.time () in
  printf "\r%s (%d runs): %.4f seconds (%.2f ops/sec)\n" 
    name count (end_time -. start_time) 
    (float_of_int count /. (end_time -. start_time));
  flush_all ()

(* Test scenarios *)

let benchmark_signal_updates () =
  printf "\n=== Signal Update Performance ===\n";
  flush_all ();
  
  (* Test 1: Simple signal updates *)
  let run_simple_updates () =
    Solid_ml_server.Runtime.run (fun () ->
      let signal, set_signal = Solid_ml_server.Signal.create 0 in
      for i = 1 to 10000 do
        set_signal i
      done
    )
  in
  
  timeit "Simple signal updates (10k)" run_simple_updates;
  
  (* Test 2: Signal with many observers *)
  let run_observers_updates () =
    Solid_ml_server.Runtime.run (fun () ->
      let signal, set_signal = Solid_ml_server.Signal.create 0 in
      
      (* Create 100 effects observing the signal *)
      for i = 1 to 100 do
        ignore @@ Solid_ml_server.Effect.create (fun () ->
          let _ = Solid_ml_server.Signal.get signal in
          ()
        )
      done;
      
      (* Update signal 1000 times *)
      for i = 1 to 1000 do
        set_signal i
      done
    )
  in
  
  timeit "Signal with 100 observers (1k updates)" run_observers_updates

let benchmark_effect_execution () =
  printf "\n=== Effect Execution Performance ===\n";
  flush_all ();
  
  (* Test 1: Many small effects *)
  let run_many_effects () =
    Solid_ml_server.Runtime.run (fun () ->
      let signals = Array.init 1000 (fun _ -> 
        fst (Solid_ml_server.Signal.create 0)
      ) in
      
      (* Create 1000 effects each observing one signal *)
      Array.iteri (fun i signal ->
        ignore @@ Solid_ml_server.Effect.create (fun () ->
          let _ = Solid_ml_server.Signal.get signal in
          ()
        )
      ) signals;
      
      (* Update all signals *)
      Array.iteri (fun i signal ->
        let _, set_signal = Solid_ml_server.Signal.create 0 in
        set_signal (i + 1)
      ) signals
    )
  in
  
  timeit "50-deep memo chain (100 updates)" run_deep_chain

let benchmark_memory_pressure () =
  printf "\n=== Memory Pressure Test ===\n";
  flush_all ();
  
  (* Test GC-heavy operations *)
  let run_memory_test () =
    Solid_ml_server.Runtime.run (fun () ->
      let signals = Array.init 100 (fun _ -> 
        fst (Solid_ml_server.Signal.create (Random.int 1000))
      ) in
      
      (* Create and dispose many effects repeatedly *)
      for i = 1 to 100 do
        let dispose = Solid_ml_server.Owner.create_root (fun () ->
          Array.iter (fun signal ->
            ignore @@ Solid_ml_server.Effect.create (fun () ->
              let _ = Solid_ml_server.Signal.get signal in
              ()
            )
          ) signals
        ) in
        dispose ()
      done
    )
  in
  
  timeit "Create/dispose effects (100x100 signals)" run_memory_test

let run_benchmarks () =
  printf "solid-ml-server Performance Benchmarks\n";
  printf "=================================\n";
  
  benchmark_signal_updates ();
  benchmark_effect_execution ();
  benchmark_memo_chains ();
  benchmark_memory_pressure ();
  
  printf "\n=== Baseline Complete ===\n"

let () = 
  if Array.length Sys.argv > 1 then
    match Sys.argv.(1) with
    | "signal" -> benchmark_signal_updates ()
    | "effect" -> benchmark_effect_execution ()
    | "memo" -> benchmark_memo_chains ()
    | "memory" -> benchmark_memory_pressure ()
    | _ -> printf "Usage: dune exec bench_bench.exe [signal|effect|memo|memory]\n"
  else
    run_benchmarks ()

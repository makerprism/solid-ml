(** Simple performance benchmarks for solid-ml *)

open Printf

let timeit name f =
  let start_time = Sys.time () in
  let result = f () in
  let end_time = Sys.time () in
  printf "%s: %.4f seconds\n" name (end_time -. start_time);
  flush_all ();
  result

let benchmark_signal_updates () =
  printf "\n=== Signal Update Performance ===\n";
  
  (* Test 1: Simple signal updates *)
  let run_simple_updates () =
    Solid_ml.Runtime.Unsafe.run (fun () ->
      let _, set_signal = Solid_ml.Signal.Unsafe.create 0 in
      for i = 1 to 10000 do
        ignore (set_signal i)
      done
    )
  in
  
  timeit "Simple signal updates (10k)" run_simple_updates

let benchmark_memo_chains () =
  printf "\n=== Memo Chain Performance ===\n";
  
  (* Test 1: Deep memo chain *)
  let run_deep_chain () =
    Solid_ml.Runtime.Unsafe.run (fun () ->
      let root_signal, set_root = Solid_ml.Signal.Unsafe.create 1 in
      
      (* Build chain of 50 memos and return chain function *)
      let rec build_chain depth signal_fn =
        if depth = 0 then signal_fn
        else
          let memo = Solid_ml.Memo.Unsafe.create (fun () ->
            let v = signal_fn () in
            v + depth
          ) in
          build_chain (depth - 1) (fun () -> Solid_ml.Memo.get memo)
      in
      
      (* Create the chain function *)
      let chain_fn = build_chain 50 (fun () -> Solid_ml.Signal.get root_signal) in
      
      (* Update root signal and run chain 100 times *)
      for i = 1 to 100 do
        ignore (set_root i);
        ignore (chain_fn ())
      done
    )
  in
  
  timeit "50-deep memo chain (100 updates)" run_deep_chain

let run_benchmarks () =
  printf "solid-ml Performance Benchmarks\n";
  printf "=================================\n";
  
  benchmark_signal_updates ();
  benchmark_memo_chains ();
  
  printf "\n=== Baseline Complete ===\n"

let () = 
  if Array.length Sys.argv > 1 then
    match Sys.argv.(1) with
    | "signal" -> benchmark_signal_updates ()
    | "memo" -> benchmark_memo_chains ()
    | _ -> printf "Usage: dune exec bench_simple.exe [signal|memo]\n"
  else
    run_benchmarks ()

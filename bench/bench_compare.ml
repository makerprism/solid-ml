(** Compare original vs optimized reactive core *)

open Printf

let timeit name f =
  let start_time = Sys.time () in
  let result = f () in
  let end_time = Sys.time () in
  printf "%s: %.4f seconds\n" name (end_time -. start_time);
  flush_all ();
  result

(* Import both versions *)
module Orig = Solid_ml_server
module Opt = Solid_ml_optimized

let benchmark_signal_updates () =
  printf "\n=== Signal Update Performance Comparison ===\n";
  
  (* Original version *)
  let run_original () =
    Orig.Runtime.run (fun () ->
      let signal, set_signal = Orig.Signal.create 0 in
      for i = 1 to 50000 do
        set_signal i
      done
    )
  in
  
  (* Optimized version *)
  let run_optimized () =
    Opt.Runtime.run (fun () ->
      let signal, set_signal = Opt.Signal.create 0 in
      for i = 1 to 50000 do
        set_signal i
      done
    )
  in
  
  timeit "Original (50k signal updates)" run_original;
  timeit "Optimized (50k signal updates)" run_optimized

let benchmark_memo_chains () =
  printf "\n=== Memo Chain Performance Comparison ===\n";
  
  (* Original version *)
  let run_original () =
    Orig.Runtime.run (fun () ->
      let root_signal, set_root = Orig.Signal.create 1 in
      
      let rec build_chain depth signal =
        if depth = 0 then
          Orig.Signal.get signal
        else
          let memo = Orig.Memo.create (fun () ->
            let v = Orig.Signal.get signal in
            v + depth
          ) in
          build_chain (depth - 1) (Orig.Memo.get memo)
      in
      
      let chain_fn = fun () -> build_chain 30 root_signal in
      
      for i = 1 to 200 do
        set_root i;
        ignore (chain_fn ())
      done
    )
  in
  
  (* Optimized version *)
  let run_optimized () =
    Opt.Runtime.run (fun () ->
      let root_signal, set_root = Opt.Signal.create 1 in
      
      let rec build_chain depth signal =
        if depth = 0 then
          Opt.Signal.get signal
        else
          let memo = Opt.Memo.create (fun () ->
            let v = Opt.Signal.get signal in
            v + depth
          ) in
          build_chain (depth - 1) (Opt.Memo.get memo)
      in
      
      let chain_fn = fun () -> build_chain 30 root_signal in
      
      for i = 1 to 200 do
        set_root i;
        ignore (chain_fn ())
      done
    )
  in
  
  timeit "Original (30-deep chain, 200 updates)" run_original;
  timeit "Optimized (30-deep chain, 200 updates)" run_optimized

let run_comparison () =
  printf "solid-ml-server Performance Comparison\n";
  printf "=================================\n";
  
  benchmark_signal_updates ();
  benchmark_memo_chains ();
  
  printf "\n=== Comparison Complete ===\n"

let () = 
  if Array.length Sys.argv > 1 then
    match Sys.argv.(1) with
    | "signal" -> benchmark_signal_updates ()
    | "memo" -> benchmark_memo_chains ()
    | _ -> printf "Usage: dune exec bench_compare.exe [signal|memo]\n"
  else
    run_comparison ()

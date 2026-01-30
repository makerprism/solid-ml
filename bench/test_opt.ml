(** Simple single optimization test: Fast equality for signals *)

open Printf

(* Test fast equality optimization in Signal.create *)
let benchmark_optimization () =
  printf "\n=== Testing Fast Equality Optimization ===\n";
  
  (* Original: slow updates with structural equality *)
  let run_slow () =
    Solid_ml.Runtime.Unsafe.run (fun () ->
      let _, set_signal = Solid_ml.Signal.Unsafe.create "" in
      for i = 1 to 100000 do
        ignore (set_signal (string_of_int i))
      done
    )
  in
  
  (* Optimized: physical equality for strings *)
  let run_fast () =
    Solid_ml.Runtime.Unsafe.run (fun () ->
      let _, set_signal = Solid_ml.Signal.Unsafe.create_physical "" in
      for i = 1 to 100000 do
        ignore (set_signal (string_of_int i))
      done
    )
  in
  
  let timeit name f =
    let start = Sys.time () in
    f ();
    let end_time = Sys.time () in
    printf "%s: %.4f seconds\n" name (end_time -. start);
  in
  
  timeit "Structural equality (100k string updates)" run_slow;
  timeit "Physical equality (100k string updates)" run_fast

let () = benchmark_optimization ()

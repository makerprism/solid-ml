(** Benchmark with observers to test optimization impact *)

open Printf

let timeit name f =
  let start_time = Sys.time () in
  let result = f () in
  let end_time = Sys.time () in
  printf "%s: %.4f seconds\n" name (end_time -. start_time);
  flush_all ();
  result

let benchmark_signal_with_observers () =
  printf "\n=== Signal with 50 observers ===\n";
  
  let run_with_observers () =
    Solid_ml.Runtime.Unsafe.run (fun () ->
      let signal, set_signal = Solid_ml.Signal.Unsafe.create 0 in
      
      (* Create 50 effects observing signal *)
      for _i = 1 to 50 do
        ignore @@ Solid_ml.Effect.Unsafe.create (fun () ->
          let _ = Solid_ml.Signal.get signal in
          ()
        )
      done;
      
      (* Update signal 1000 times *)
      for i = 1 to 1000 do
        set_signal i
      done
    )
  in
  
  timeit "Signal with 50 observers (1k updates)" run_with_observers

let () = 
  benchmark_signal_with_observers ()

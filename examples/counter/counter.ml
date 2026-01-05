(** A simple counter example demonstrating solid-ml reactive primitives.

    This example runs in native OCaml (no browser) and shows:
    - Creating signals for state
    - Using effects for side effects (printing)
    - Using memos for derived values
    - Ownership and cleanup
    - Runtime isolation

    Run with: dune exec examples/counter/counter.exe
*)

open Solid_ml

(** Helper to run example within a runtime *)
let run_example name fn =
  print_endline ("=== " ^ name ^ " ===\n");
  Runtime.run (fun () ->
    let dispose = Owner.create_root fn in
    dispose ()
  );
  print_endline ""

(** Simple counter with derived values *)
let counter_example () =
  run_example "Counter Example" (fun () ->
    (* Create a signal for the count *)
    let count, set_count = Signal.create 0 in
    
    (* Create a memo for doubled value *)
    let doubled = Memo.create (fun () ->
      Signal.get count * 2
    ) in
    
    (* Create a memo for a formatted message *)
    let message = Memo.create (fun () ->
      let c = Signal.get count in
      let d = Signal.get doubled in
      Printf.sprintf "Count: %d, Doubled: %d" c d
    ) in
    
    (* Effect that prints whenever the message changes *)
    Effect.create (fun () ->
      print_endline (Signal.get message)
    );
    
    (* Increment the counter *)
    print_endline "\n[Incrementing...]";
    set_count 1;
    
    print_endline "\n[Incrementing...]";
    set_count 2;
    
    print_endline "\n[Setting to 10...]";
    Signal.set count 10;
    
    print_endline "\n[Using update function...]";
    Signal.update count (fun n -> n + 5)
  )

(** Example with cleanup *)
let cleanup_example () =
  print_endline "=== Cleanup Example ===\n";
  
  Runtime.run (fun () ->
    (* Signal lives outside the disposable root *)
    let count, set_count = Signal.create 0 in
    
    (* Create a root that owns the effect *)
    let dispose = Owner.create_root (fun () ->
      Effect.create_with_cleanup (fun () ->
        let c = Signal.get count in
        print_endline (Printf.sprintf "Effect running, count = %d" c);
        (* Return cleanup function *)
        fun () ->
          print_endline (Printf.sprintf "  Cleaning up from count = %d" c)
      )
    ) in
    
    print_endline "\n[Updating count...]";
    set_count 1;
    
    print_endline "\n[Updating count again...]";
    set_count 2;
    
    print_endline "\n[Disposing root...]";
    dispose ();
    
    print_endline "\n[Updating after dispose (no effect)...]";
    set_count 3;
    print_endline "(Effect no longer runs)"
  );
  
  print_endline ""

(** Example with conditional dependencies *)
let conditional_example () =
  run_example "Conditional Dependencies Example" (fun () ->
    let use_celsius, set_use_celsius = Signal.create true in
    let celsius, set_celsius = Signal.create 20.0 in
    let fahrenheit, set_fahrenheit = Signal.create 68.0 in
    
    (* This effect only tracks the currently active temperature *)
    Effect.create (fun () ->
      let temp =
        if Signal.get use_celsius then
          Printf.sprintf "%.1f°C" (Signal.get celsius)
        else
          Printf.sprintf "%.1f°F" (Signal.get fahrenheit)
      in
      print_endline ("Temperature: " ^ temp)
    );
    
    print_endline "\n[Changing Celsius (tracked)...]";
    set_celsius 25.0;
    
    print_endline "\n[Changing Fahrenheit (NOT tracked while in Celsius mode)...]";
    set_fahrenheit 100.0;
    print_endline "(No output - Fahrenheit not tracked)";
    
    print_endline "\n[Switching to Fahrenheit mode...]";
    set_use_celsius false;
    
    print_endline "\n[Changing Fahrenheit (now tracked)...]";
    set_fahrenheit 72.0;
    
    print_endline "\n[Changing Celsius (no longer tracked)...]";
    set_celsius 30.0;
    print_endline "(No output - Celsius no longer tracked)"
  )

(** Example with context *)
let context_example () =
  run_example "Context Example" (fun () ->
    (* Create a "theme" context *)
    let theme_context = Context.create "light" in
    
    let print_theme label =
      print_endline (Printf.sprintf "%s: theme = %s" label (Context.use theme_context))
    in
    
    print_theme "Default";
    
    Context.provide theme_context "dark" (fun () ->
      print_theme "In dark provider";
      
      Context.provide theme_context "high-contrast" (fun () ->
        print_theme "In nested high-contrast provider"
      );
      
      print_theme "Back to dark"
    );
    
    print_theme "Outside providers (back to default)"
  )

(** Example with batching *)
let batch_example () =
  run_example "Batch Example" (fun () ->
    let first_name, set_first = Signal.create "John" in
    let last_name, set_last = Signal.create "Doe" in
    
    let effect_count = ref 0 in
    
    let full_name = Memo.create (fun () ->
      Signal.get first_name ^ " " ^ Signal.get last_name
    ) in
    
    Effect.create (fun () ->
      incr effect_count;
      print_endline (Printf.sprintf "[Run %d] Full name: %s" !effect_count (Signal.get full_name))
    );
    
    print_endline "\n[Without batch - two separate updates:]";
    set_first "Jane";
    set_last "Smith";
    
    print_endline "\n[With batch - single update:]";
    Batch.run (fun () ->
      set_first "Bob";
      set_last "Johnson"
    )
  )

(** Main entry point *)
let () =
  counter_example ();
  cleanup_example ();
  conditional_example ();
  context_example ();
  batch_example ();
  print_endline "=== All examples completed! ==="

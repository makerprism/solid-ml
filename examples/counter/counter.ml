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
  Runtime.run (fun token ->
    let dispose = Owner.create_root token (fun () -> fn token) in
    dispose ()
  );
  print_endline ""

(** Simple counter with derived values *)
let counter_example () =
  run_example "Counter Example" (fun token ->
    (* Create a signal for the count *)
    let count, _set_count = Signal.create token 0 in

    (* Idiomatic: use plain function for simple derived state *)
    (* Only use Memo.create for expensive computations that need explicit caching *)
    let doubled () = Signal.get count * 2 in

    (* Derived computation combining signals and other derived values *)
    let message () =
      let c = Signal.get count in
      let d = doubled () in
      Printf.sprintf "Count: %d, Doubled: %d" c d
    in

    (* Effect that prints whenever the message changes *)
    Effect.create token (fun () ->
      print_endline (message ())
    );

    (* Increment the counter *)
    print_endline "\n[Incrementing...]";
    Signal.set count 1;

    print_endline "\n[Incrementing...]";
    Signal.set count 2;

    print_endline "\n[Setting to 10...]";
    Signal.set count 10;

    print_endline "\n[Using update function...]";
    Signal.update count (fun n -> n + 5)
  )

(** Example with cleanup *)
let cleanup_example () =
  print_endline "=== Cleanup Example ===\n";

  Runtime.run (fun token ->
    (* Signal lives outside the disposable root *)
    let count, _set_count = Signal.create token 0 in

    (* Create a root that owns the effect *)
    let dispose =
      Owner.create_root token (fun () ->
        Effect.create_with_cleanup token (fun () ->
          let c = Signal.get count in
          print_endline (Printf.sprintf "Effect running, count = %d" c);
          (* Return cleanup function *)
          fun () ->
            print_endline (Printf.sprintf "  Cleaning up from count = %d" c)
        )
      )
    in

    print_endline "\n[Updating count...]";
    Signal.set count 1;

    print_endline "\n[Updating count again...]";
    Signal.set count 2;

    print_endline "\n[Disposing root...]";
    dispose ();

    print_endline "\n[Updating after dispose (no effect)...]";
    Signal.set count 3;
    print_endline "(Effect no longer runs)"
  );
  
  print_endline ""

(** Example with conditional dependencies *)
let conditional_example () =
  run_example "Conditional Dependencies Example" (fun token ->
    let use_celsius, _set_use_celsius = Signal.create token true in
    let celsius, _set_celsius = Signal.create token 20.0 in
    let fahrenheit, _set_fahrenheit = Signal.create token 68.0 in
    
    (* This effect only tracks the currently active temperature *)
    Effect.create token (fun () ->
      let temp =
        if Signal.get use_celsius then
          Printf.sprintf "%.1f°C" (Signal.get celsius)
        else
          Printf.sprintf "%.1f°F" (Signal.get fahrenheit)
      in
      print_endline ("Temperature: " ^ temp)
    );
    
    print_endline "\n[Changing Celsius (tracked)...]";
    Signal.set celsius 25.0;
    
    print_endline "\n[Changing Fahrenheit (NOT tracked while in Celsius mode)...]";
    Signal.set fahrenheit 100.0;
    print_endline "(No output - Fahrenheit not tracked)";
    
    print_endline "\n[Switching to Fahrenheit mode...]";
    Signal.set use_celsius false;
    
    print_endline "\n[Changing Fahrenheit (now tracked)...]";
    Signal.set fahrenheit 72.0;
    
    print_endline "\n[Changing Celsius (no longer tracked)...]";
    Signal.set celsius 30.0;
    print_endline "(No output - Celsius no longer tracked)"
  )

(** Example with context *)
let context_example () =
  run_example "Context Example" (fun _token ->
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
  run_example "Batch Example" (fun token ->
    let first_name, _set_first_name = Signal.create token "John" in
    let last_name, _set_last_name = Signal.create token "Doe" in

    let effect_count = ref 0 in

    (* Idiomatic: use plain function for simple derived state *)
    let full_name () =
      Signal.get first_name ^ " " ^ Signal.get last_name
    in

    Effect.create token (fun () ->
      incr effect_count;
      print_endline (Printf.sprintf "[Run %d] Full name: %s" !effect_count (full_name ()))
    );

    print_endline "\n[Without batch - two separate updates:]";
    Signal.set first_name "Jane";
    Signal.set last_name "Smith";

    print_endline "\n[With batch - single update:]";
    Batch.run token (fun () ->
      Signal.set first_name "Bob";
      Signal.set last_name "Johnson"
    );

    print_endline "";
    print_endline "Use Batch.run when:";
    print_endline "  - Updating multiple signals that should trigger effects once";
    print_endline "  - Doing bulk operations (arrays, lists, forms)";
    print_endline "  - Preventing unnecessary intermediate re-renders";
    print_endline "";
    print_endline "Common patterns:";
    print_endline "  Batch.run (fun () ->";
    print_endline "    set_loading true;";
    print_endline "    set_error None;";
    print_endline "    async_request ()";
    print_endline "  );";
    print_endline "";
    print_endline "  Batch.run (fun () ->";
    print_endline "    update_multiple_form_fields ();";
    print_endline "    set_dirty true";
    print_endline "  );"
  )

(** Main entry point *)
let () =
  counter_example ();
  cleanup_example ();
  conditional_example ();
  context_example ();
  batch_example ();
  print_endline "=== All examples completed! ==="

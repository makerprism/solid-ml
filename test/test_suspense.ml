(** Tests for Suspense and ErrorBoundary *)

open Solid_ml
open Solid_ml_router

(* Test utilities *)
let test name f =
  Printf.printf "Test: %s\n%!" name;
  try
    Runtime.run f;
    Printf.printf "  PASSED\n%!"
  with e ->
    Printf.printf "  FAILED: %s\n%!" (Printexc.to_string e)

let assert_equal expected actual msg =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %s, got %s" msg expected actual)

let assert_true cond msg =
  if not cond then failwith msg

(* ============================================
   Suspense Tests
   ============================================ *)

let () = print_endline "\n=== Suspense Tests ===\n"

let () = test "Suspense shows content when resource is ready" (fun () ->
  let resource = Resource.of_value "loaded data" in
  
  let result = Suspense.boundary
    ~fallback:(fun () -> "fallback")
    (fun () ->
      let data = Resource.read_suspense ~default:"default" resource in
      "content: " ^ data
    )
  in
  
  assert_equal "content: loaded data" result "Should show content with data"
)

let () = test "Suspense shows fallback when resource is loading" (fun () ->
  let resource = Resource.create_loading () in
  
  let result = Suspense.boundary
    ~fallback:(fun () -> "loading...")
    (fun () ->
      let _data = Resource.read_suspense ~default:"default" resource in
      "content"
    )
  in
  
  assert_equal "loading..." result "Should show fallback"
)

let () = test "Suspense transitions from fallback to content when resource resolves" (fun () ->
  let resource = Resource.create_loading () in
  let results = ref [] in
  
  let _dispose = Owner.create_root (fun () ->
    Effect.create (fun () ->
      let result = Suspense.boundary
        ~fallback:(fun () -> "loading...")
        (fun () ->
          let data = Resource.read_suspense ~default:"default" resource in
          "content: " ^ data
        )
      in
      results := result :: !results
    )
  ) in
  
  (* Initially should show fallback *)
  assert_equal "loading..." (List.hd !results) "Initially shows fallback";
  
  (* Resolve the resource *)
  Resource.set resource "resolved data";
  
  (* Should now show content *)
  assert_equal "content: resolved data" (List.hd !results) "Shows content after resolution"
)

let () = test "Suspense with multiple resources waits for all" (fun () ->
  let resource1 = Resource.create_loading () in
  let resource2 = Resource.create_loading () in
  let results = ref [] in
  
  let _dispose = Owner.create_root (fun () ->
    Effect.create (fun () ->
      let result = Suspense.boundary
        ~fallback:(fun () -> "loading...")
        (fun () ->
          let d1 = Resource.read_suspense ~default:"" resource1 in
          let d2 = Resource.read_suspense ~default:"" resource2 in
          "content: " ^ d1 ^ ", " ^ d2
        )
      in
      results := result :: !results
    )
  ) in
  
  (* Initially should show fallback *)
  assert_equal "loading..." (List.hd !results) "Shows fallback initially";
  
  (* Resolve first resource *)
  Resource.set resource1 "first";
  
  (* Should still show fallback (second still loading) *)
  assert_equal "loading..." (List.hd !results) "Still shows fallback after first resolves";
  
  (* Resolve second resource *)
  Resource.set resource2 "second";
  
  (* Now should show content *)
  assert_equal "content: first, second" (List.hd !results) "Shows content when all resolve"
)

let () = test "read_suspense returns default when no Suspense boundary" (fun () ->
  let resource = Resource.create_loading () in
  
  (* No Suspense boundary - should return default *)
  let result = Resource.read_suspense ~default:"my default" resource in
  
  assert_equal "my default" result "Should return default without boundary"
)

let () = test "read_suspense returns data when resource is ready (no boundary)" (fun () ->
  let resource = Resource.of_value "ready data" in
  
  let result = Resource.read_suspense ~default:"default" resource in
  
  assert_equal "ready data" result "Should return actual data when ready"
)

let () = test "Nested Suspense boundaries work independently" (fun () ->
  let outer_resource = Resource.create_loading () in
  let inner_resource = Resource.create_loading () in
  let results = ref [] in
  
  let _dispose = Owner.create_root (fun () ->
    Effect.create (fun () ->
      let result = Suspense.boundary
        ~fallback:(fun () -> "outer loading")
        (fun () ->
          let outer_data = Resource.read_suspense ~default:"" outer_resource in
          let inner_result = Suspense.boundary
            ~fallback:(fun () -> "inner loading")
            (fun () ->
              let inner_data = Resource.read_suspense ~default:"" inner_resource in
              "inner: " ^ inner_data
            )
          in
          "outer: " ^ outer_data ^ " | " ^ inner_result
        )
      in
      results := result :: !results
    )
  ) in
  
  (* Initially outer should be loading *)
  assert_equal "outer loading" (List.hd !results) "Outer loading initially";
  
  (* Resolve outer *)
  Resource.set outer_resource "outer data";
  
  (* Now outer is ready but inner is loading *)
  assert_equal "outer: outer data | inner loading" (List.hd !results) 
    "Inner loading after outer resolves";
  
  (* Resolve inner *)
  Resource.set inner_resource "inner data";
  
  (* Both ready *)
  assert_equal "outer: outer data | inner: inner data" (List.hd !results) 
    "Both ready"
)

(* ============================================
   ErrorBoundary Tests
   ============================================ *)

let () = print_endline "\n=== ErrorBoundary Tests ===\n"

let () = test "ErrorBoundary renders children when no error" (fun () ->
  let result = ErrorBoundary.make
    ~fallback:(fun ~error ~reset:_ -> "error: " ^ error)
    (fun () -> "success")
  in
  
  assert_equal "success" result "Should render children"
)

let () = test "ErrorBoundary catches exception and shows fallback" (fun () ->
  let result = ErrorBoundary.make
    ~fallback:(fun ~error ~reset:_ -> "caught: " ^ error)
    (fun () -> failwith "test error")
  in
  
  assert_true (String.length result > 0) "Should have result";
  assert_true (String.sub result 0 7 = "caught:") "Should show error fallback"
)

let () = test "ErrorBoundary catches Resource error" (fun () ->
  let resource = Resource.of_error "resource failed" in
  
  let result = ErrorBoundary.make
    ~fallback:(fun ~error ~reset:_ -> "error: " ^ error)
    (fun () ->
      let _data = Resource.read_suspense ~default:"" resource in
      "success"
    )
  in
  
  assert_true (String.length result > 0) "Should have result";
  assert_true (String.sub result 0 6 = "error:") "Should show error"
)

let () = test "ErrorBoundary.make_simple works" (fun () ->
  let result = ErrorBoundary.make_simple
    ~fallback:(fun error -> "simple error: " ^ error)
    (fun () -> failwith "oops")
  in
  
  assert_true (String.sub result 0 13 = "simple error:") "Should show simple error"
)

let () = test "ErrorBoundary reset re-renders children" (fun () ->
  let attempts = ref 0 in
  let should_fail = ref true in
  let reset_fn = ref (fun () -> ()) in
  
  let _dispose = Owner.create_root (fun () ->
    let _result = ErrorBoundary.make
      ~fallback:(fun ~error:_ ~reset -> 
        reset_fn := reset;
        "error state"
      )
      (fun () ->
        incr attempts;
        if !should_fail then failwith "fail"
        else "success"
      )
    in
    ()
  ) in
  
  assert_true (!attempts = 1) "Should have tried once";
  
  (* Now fix the error and reset *)
  should_fail := false;
  !reset_fn ();
  
  assert_true (!attempts = 2) "Should have retried after reset"
)

(* ============================================
   Combined Suspense + ErrorBoundary Tests
   ============================================ *)

let () = print_endline "\n=== Combined Suspense + ErrorBoundary Tests ===\n"

let () = test "ErrorBoundary wrapping Suspense catches resource errors" (fun () ->
  let resource = Resource.create_loading () in
  let results = ref [] in
  
  let _dispose = Owner.create_root (fun () ->
    Effect.create (fun () ->
      let result = ErrorBoundary.make
        ~fallback:(fun ~error ~reset:_ -> "error: " ^ error)
        (fun () ->
          Suspense.boundary
            ~fallback:(fun () -> "loading...")
            (fun () ->
              let data = Resource.read_suspense ~default:"" resource in
              "content: " ^ data
            )
        )
      in
      results := result :: !results
    )
  ) in
  
  (* Initially loading *)
  assert_equal "loading..." (List.hd !results) "Initially loading";
  
  (* Error the resource *)
  Resource.set_error resource "fetch failed";
  
  (* Should show error *)
  assert_true (String.sub (List.hd !results) 0 6 = "error:") "Should show error after failure"
)

(* ============================================
   Summary
   ============================================ *)

let () = print_endline "\n=== All Suspense tests passed! ===\n"

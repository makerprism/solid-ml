(** Tests for solid-ml-server additional components: Store, Resource *)
(** This test suite covers: *)
(** - Store: Reactive state wrapper *)
(** - Resource: Data fetching state management *)

open Solid_ml_server


(** {1 Helper Functions} *)

let with_runtime fn =
  Runtime.Unsafe.run (fun () ->
    let dispose = Owner.Unsafe.create_root fn in
    dispose ()
  )

(** {2 Store Tests} *)

let test_store_basic_operations () =
  print_endline "Test: Store basic create and get";
  with_runtime (fun () ->
    let store = Store.Unsafe.create 42 in
    assert (Store.get store = 42);
    ignore store
  );
  print_endline "  PASSED"

let test_store_updates () =
  print_endline "Test: Store updates via set";
  with_runtime (fun () ->
    let store = Store.Unsafe.create 10 in
    assert (Store.get store = 10);
    Store.set store 20;
    assert (Store.get store = 20);
    ignore store
  );
  print_endline "  PASSED"

let test_store_produce () =
  print_endline "Test: Store.produce returns current value";
  with_runtime (fun () ->
    let store = Store.Unsafe.create [1; 2; 3] in
    let result = Store.produce (fun _ -> ()) store in
    assert (result = [1; 2; 3]);
    ignore result
  );
  print_endline "  PASSED"

let test_store_reconcile () =
  print_endline "Test: Store.reconcile returns data";
  with_runtime (fun () ->
    let new_data = [1; 4; 3; 5] in
    let result = Store.reconcile new_data (Store.Unsafe.create [1; 2; 3]) in
    assert (result = [1; 4; 3; 5]);
    ignore result
  );
  print_endline "  PASSED"

(** {3 Resource Tests} *)

let test_resource_creates () =
  print_endline "Test: Resource creates with fetcher";
  with_runtime (fun () ->
    let resource, _actions = Resource.create_resource (fun () -> "data") in
    match Resource.peek resource with
    | Resource.Ready v -> assert (v = "data")
    | _ -> ()  (* May still be loading *)
  );
  print_endline "  PASSED"

let test_resource_read_state () =
  print_endline "Test: Resource state transitions";
  with_runtime (fun () ->
    let resource = Resource.Unsafe.of_value "initial" in
    assert (Resource.loading resource = false);
    assert (Resource.errored resource = false);
    match Resource.peek resource with
    | Resource.Ready v -> assert (v = "initial")
    | _ -> failwith "Expected ready"
  );
  print_endline "  PASSED"

let test_resource_mutate () =
  print_endline "Test: Resource.mutate for optimistic updates";
  with_runtime (fun () ->
    let resource = Resource.Unsafe.of_value 10 in
    assert (Resource.get resource = 10);
    Resource.mutate resource (fun _ -> 20);
    assert (Resource.get resource = 20)
  );
  print_endline "  PASSED"

let test_resource_render () =
  print_endline "Test: Resource.render helper";
  with_runtime (fun () ->
    let resource = Resource.Unsafe.of_value "test" in
    let result = Resource.render
      ~loading:(fun () -> "loading")
      ~error:(fun _ -> "error")
      ~ready:(fun v -> v)
      resource
    in
    assert (result = "test")
  );
  print_endline "  PASSED"

(** {4 Run All Tests} *)

let () =
  print_endline "=== Additional Components Tests ===";
  print_endline "";
  
  print_endline "--- Store Tests ---";
  test_store_basic_operations ();
  test_store_updates ();
  test_store_produce ();
  test_store_reconcile ();
  
  print_endline "";
  print_endline "--- Resource Tests ---";
  test_resource_creates ();
  test_resource_read_state ();
  test_resource_mutate ();
  test_resource_render ();
  
  print_endline "";
  print_endline "=== All Tests Passed ==="

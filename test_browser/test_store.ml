(** Browser Store module tests.
    
    These tests verify the Store module with lens-based nested reactive state.
    
    Run with: make browser-tests
*)

open Solid_ml_browser
open Reactive_core

(* Test helpers *)
external console_log : string -> unit = "log" [@@mel.scope "console"]

let passed = ref 0
let failed = ref 0

let test name fn =
  console_log ("Test: " ^ name);
  try
    fn ();
    incr passed;
    console_log "  PASSED"
  with exn ->
    incr failed;
    console_log ("  FAILED: " ^ Printexc.to_string exn)

let assert_eq a b =
  if a <> b then failwith "assertion failed: values not equal"

let assert_true b =
  if not b then failwith "assertion failed: expected true"

(* Ensure we have a runtime for tests *)
let with_runtime f =
  let (_, dispose) = create_root (fun () -> f ()) in
  dispose ()

(* ============ Test Types ============ *)

type user = {
  name: string;
  age: int;
}

type state = {
  users: user list;
  count: int;
  active: bool;
}

(* Define lenses for the test types *)
let users_lens : (state, user list) Store.lens = 
  Store.Lens.make 
    ~get:(fun s -> s.users) 
    ~set:(fun s v -> { s with users = v })

let count_lens : (state, int) Store.lens = 
  Store.Lens.make 
    ~get:(fun s -> s.count) 
    ~set:(fun s v -> { s with count = v })

let active_lens : (state, bool) Store.lens =
  Store.Lens.make
    ~get:(fun s -> s.active)
    ~set:(fun s v -> { s with active = v })

let name_lens : (user, string) Store.lens =
  Store.Lens.make
    ~get:(fun u -> u.name)
    ~set:(fun u v -> { u with name = v })

let age_lens : (user, int) Store.lens =
  Store.Lens.make
    ~get:(fun u -> u.age)
    ~set:(fun u v -> { u with age = v })

let initial_state = {
  users = [{ name = "Alice"; age = 30 }; { name = "Bob"; age = 25 }];
  count = 0;
  active = true;
}

(* ============ Lens Tests ============ *)

let test_lens_id () =
  test "Lens.id focuses on whole" (fun () ->
    let x = 42 in
    assert_eq (Store.Lens.get Store.Lens.id x) 42;
    assert_eq (Store.Lens.set Store.Lens.id x 100) 100
  )

let test_lens_compose () =
  test "Lens composition works" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      (* Compose: users -> nth 0 -> name *)
      let first_user_name = 
        Store.Lens.(users_lens |-- nth 0 |-- name_lens) in
      
      assert_eq (Store.get store first_user_name) "Alice";
      
      Store.set store first_user_name "Alicia";
      assert_eq (Store.get store first_user_name) "Alicia"
    )
  )

let test_lens_nth () =
  test "Lens.nth accesses list elements" (fun () ->
    let xs = [10; 20; 30] in
    assert_eq (Store.Lens.get (Store.Lens.nth 1) xs) 20;
    
    let xs' = Store.Lens.set (Store.Lens.nth 1) xs 25 in
    assert_eq (Store.Lens.get (Store.Lens.nth 1) xs') 25
  )

let test_lens_head () =
  test "Lens.head accesses first element" (fun () ->
    let xs = [1; 2; 3] in
    assert_eq (Store.Lens.get Store.Lens.head xs) 1;
    
    let xs' = Store.Lens.set Store.Lens.head xs 10 in
    assert_eq (List.hd xs') 10
  )

let test_lens_fst_snd () =
  test "Lens.fst and Lens.snd access tuple elements" (fun () ->
    let pair = (1, "hello") in
    assert_eq (Store.Lens.get Store.Lens.fst pair) 1;
    assert_eq (Store.Lens.get Store.Lens.snd pair) "hello";
    
    let pair' = Store.Lens.set Store.Lens.fst pair 42 in
    assert_eq (fst pair') 42;
    assert_eq (snd pair') "hello"
  )

let test_lens_update () =
  test "Lens.update applies function" (fun () ->
    let x = (10, 20) in
    let x' = Store.Lens.update Store.Lens.fst x (fun n -> n + 5) in
    assert_eq (fst x') 15
  )

(* ============ Store Basic Tests ============ *)

let test_store_create () =
  test "Store.create initializes state" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let s = Store.get_all store in
      assert_eq s.count 0;
      assert_eq (List.length s.users) 2
    )
  )

let test_store_get_set () =
  test "Store.get and Store.set through lens" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      assert_eq (Store.get store count_lens) 0;
      
      Store.set store count_lens 5;
      assert_eq (Store.get store count_lens) 5
    )
  )

let test_store_update () =
  test "Store.update applies function through lens" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      Store.update store count_lens (fun c -> c + 10);
      assert_eq (Store.get store count_lens) 10;
      
      Store.update store count_lens (fun c -> c * 2);
      assert_eq (Store.get store count_lens) 20
    )
  )

let test_store_version () =
  test "Store.version increments on updates" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      let v0 = Store.version store in
      Store.set store count_lens 1;
      let v1 = Store.version store in
      Store.set store count_lens 2;
      let v2 = Store.version store in
      
      assert_true (v1 > v0);
      assert_true (v2 > v1)
    )
  )

let test_store_peek () =
  test "Store.peek doesn't track dependencies" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let runs = ref 0 in
      
      create_effect (fun () ->
        incr runs;
        let _ = Store.peek store count_lens in
        ()
      );
      
      assert_eq !runs 1;
      Store.set store count_lens 10;
      (* Effect should NOT re-run because we used peek *)
      assert_eq !runs 1
    )
  )

(* ============ Store Reactivity Tests ============ *)

let test_store_reactive () =
  test "Store updates trigger effects" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let observed = ref 0 in
      
      create_effect (fun () ->
        observed := Store.get store count_lens
      );
      
      assert_eq !observed 0;
      Store.set store count_lens 42;
      assert_eq !observed 42
    )
  )

let test_store_nested_reactive () =
  test "Nested store updates trigger effects" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let observed_name = ref "" in
      
      let first_user_name = Store.Lens.(users_lens |-- nth 0 |-- name_lens) in
      
      create_effect (fun () ->
        observed_name := Store.get store first_user_name
      );
      
      assert_eq !observed_name "Alice";
      Store.set store first_user_name "Carol";
      assert_eq !observed_name "Carol"
    )
  )

let test_store_batch () =
  test "Store.batch groups updates" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let runs = ref 0 in
      
      create_effect (fun () ->
        incr runs;
        let _ = Store.get store count_lens in
        let _ = Store.get store active_lens in
        ()
      );
      
      assert_eq !runs 1;
      
      Store.batch (fun () ->
        Store.set store count_lens 10;
        Store.set store active_lens false
      );
      
      (* Should only trigger one additional effect run *)
      assert_eq !runs 2
    )
  )

(* ============ Store Derive Tests ============ *)

let test_store_derive () =
  test "Store.derive creates memo from lens" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let derived = Store.derive store count_lens in
      
      assert_eq (get_memo derived) 0;
      
      Store.set store count_lens 100;
      assert_eq (get_memo derived) 100
    )
  )

(* ============ Store List Operations Tests ============ *)

let test_store_push () =
  test "Store.push appends to list" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      let new_user = { name = "Charlie"; age = 35 } in
      Store.push store users_lens new_user;
      
      let users = Store.get store users_lens in
      assert_eq (List.length users) 3;
      assert_eq (List.nth users 2).name "Charlie"
    )
  )

let test_store_unshift () =
  test "Store.unshift prepends to list" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      let new_user = { name = "First"; age = 20 } in
      Store.unshift store users_lens new_user;
      
      let users = Store.get store users_lens in
      assert_eq (List.length users) 3;
      assert_eq (List.hd users).name "First"
    )
  )

let test_store_filter () =
  test "Store.filter removes matching items" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      (* Keep only users older than 26 *)
      Store.filter store users_lens (fun u -> u.age > 26);
      
      let users = Store.get store users_lens in
      assert_eq (List.length users) 1;
      assert_eq (List.hd users).name "Alice"
    )
  )

let test_store_map_list () =
  test "Store.map_list transforms items" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      (* Age everyone by 1 year *)
      Store.map_list store users_lens (fun u -> { u with age = u.age + 1 });
      
      let users = Store.get store users_lens in
      assert_eq (List.hd users).age 31;
      assert_eq (List.nth users 1).age 26
    )
  )

let test_store_find_update () =
  test "Store.find_update modifies first match" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      Store.find_update store users_lens
        ~find:(fun u -> u.name = "Bob")
        ~f:(fun u -> { u with age = 100 });
      
      let users = Store.get store users_lens in
      let bob = List.find (fun u -> u.name = "Bob") users in
      assert_eq bob.age 100
    )
  )

(* ============ Store Produce Tests ============ *)

let test_store_produce () =
  test "Store.produce updates entire state" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      Store.produce store (fun s -> { s with count = s.count + 1; active = false });
      
      assert_eq (Store.get store count_lens) 1;
      assert_eq (Store.get store active_lens) false
    )
  )

let test_store_produce_at () =
  test "Store.produce_at updates focused value" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      Store.produce_at store count_lens (fun c -> c * 10 + 5);
      assert_eq (Store.get store count_lens) 5
    )
  )

(* ============ Store Subscription Tests ============ *)

let test_store_subscribe () =
  test "Store.subscribe notifies on changes" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let log = ref [] in
      
      let _unsubscribe = Store.subscribe store count_lens (fun c ->
        log := c :: !log
      ) in
      
      (* Initial call *)
      assert_eq !log [0];
      
      Store.set store count_lens 1;
      assert_eq !log [1; 0];
      
      Store.set store count_lens 2;
      assert_eq !log [2; 1; 0]
    )
  )

let test_store_subscribe_unsubscribe () =
  test "Store.subscribe unsubscribe stops notifications" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let log = ref [] in
      
      let unsubscribe = Store.subscribe store count_lens (fun c ->
        log := c :: !log
      ) in
      
      assert_eq !log [0];
      
      Store.set store count_lens 1;
      assert_eq !log [1; 0];
      
      (* Unsubscribe *)
      unsubscribe ();
      
      Store.set store count_lens 2;
      (* Should not receive the update *)
      assert_eq !log [1; 0]
    )
  )

(* ============ Store Slice Tests ============ *)

let test_store_slice () =
  test "Store slices provide scoped access" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let count_slice = Store.slice store count_lens in
      
      assert_eq (Store.slice_get count_slice) 0;
      
      Store.slice_set count_slice 50;
      assert_eq (Store.slice_get count_slice) 50;
      assert_eq (Store.get store count_lens) 50
    )
  )

let test_store_slice_compose () =
  test "Store slices can be composed with lenses" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let users_slice = Store.slice store users_lens in
      
      (* Compose slice with nth lens *)
      let first_user_slice = Store.(users_slice |-> Lens.nth 0) in
      
      let first = Store.slice_get first_user_slice in
      assert_eq first.name "Alice";
      
      Store.slice_set first_user_slice { name = "Zoe"; age = 28 };
      
      let updated = Store.slice_get first_user_slice in
      assert_eq updated.name "Zoe"
    )
  )

(* ============ Store Reconcile Tests ============ *)

let test_store_reconcile () =
  test "Store.reconcile merges lists by key" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      
      (* New data - Bob updated, Charlie new, Alice removed *)
      let new_users = [
        { name = "Bob"; age = 30 };  (* updated *)
        { name = "Charlie"; age = 22 };  (* new *)
      ] in
      
      Store.reconcile store users_lens
        ~get_key:(fun u -> u.name)
        ~merge:(fun old_user new_user -> 
          (* Keep old user's name but use new age *)
          { old_user with age = new_user.age })
        new_users;
      
      let users = Store.get store users_lens in
      assert_eq (List.length users) 2;
      
      let bob = List.find (fun u -> u.name = "Bob") users in
      assert_eq bob.age 30  (* merged *)
    )
  )

(* ============ Store on_change Tests ============ *)

let test_store_on_change () =
  test "Store.on_change watches focused value" (fun () ->
    with_runtime (fun () ->
      let store = Store.create initial_state in
      let changes = ref [] in
      
      Store.on_change store count_lens (fun c ->
        changes := c :: !changes
      );
      
      assert_eq !changes [0];  (* initial *)
      
      Store.set store count_lens 5;
      assert_eq !changes [5; 0]
    )
  )

(* ============ Run All Tests ============ *)

let () =
  console_log "\n=== Browser Store Tests ===\n";
  
  console_log "-- Lens Tests --";
  test_lens_id ();
  test_lens_compose ();
  test_lens_nth ();
  test_lens_head ();
  test_lens_fst_snd ();
  test_lens_update ();
  
  console_log "\n-- Store Basic Tests --";
  test_store_create ();
  test_store_get_set ();
  test_store_update ();
  test_store_version ();
  test_store_peek ();
  
  console_log "\n-- Store Reactivity Tests --";
  test_store_reactive ();
  test_store_nested_reactive ();
  test_store_batch ();
  
  console_log "\n-- Store Derive Tests --";
  test_store_derive ();
  
  console_log "\n-- Store List Operations Tests --";
  test_store_push ();
  test_store_unshift ();
  test_store_filter ();
  test_store_map_list ();
  test_store_find_update ();
  
  console_log "\n-- Store Produce Tests --";
  test_store_produce ();
  test_store_produce_at ();
  
  console_log "\n-- Store Subscription Tests --";
  test_store_subscribe ();
  test_store_subscribe_unsubscribe ();
  
  console_log "\n-- Store Slice Tests --";
  test_store_slice ();
  test_store_slice_compose ();
  
  console_log "\n-- Store Reconcile Tests --";
  test_store_reconcile ();
  
  console_log "\n-- Store on_change Tests --";
  test_store_on_change ();
  
  console_log "\n=== Store Results ===";
  console_log ("Passed: " ^ string_of_int !passed);
  console_log ("Failed: " ^ string_of_int !failed);
  
  if !failed > 0 then
    console_log "\n*** SOME STORE TESTS FAILED ***"
  else
    console_log "\n=== All store tests passed! ==="

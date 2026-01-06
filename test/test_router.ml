(** Router tests *)

open Solid_ml_router

let passed = ref 0
let failed = ref 0

let test name f =
  try
    f ();
    incr passed;
    Printf.printf "  PASS: %s\n" name
  with e ->
    incr failed;
    Printf.printf "  FAIL: %s - %s\n" name (Printexc.to_string e)

let assert_equal a b =
  if a <> b then failwith "assertion failed"

let assert_some = function
  | Some _ -> ()
  | None -> failwith "expected Some, got None"

let assert_none = function
  | None -> ()
  | Some _ -> failwith "expected None, got Some"

(* ========== Pattern Parsing Tests ========== *)

let test_pattern_parsing () =
  print_endline "\n=== Pattern Parsing ===";
  
  test "parse empty path" (fun () ->
    (* "/" parses to empty static *)
    let route = Route.create ~path:"/" ~data:() in
    assert_some (Route.match_route route "/")
  );
  
  test "parse static path" (fun () ->
    let route = Route.create ~path:"/users" ~data:() in
    assert_some (Route.match_route route "/users")
  );
  
  test "parse multi-segment static" (fun () ->
    let route = Route.create ~path:"/users/profile" ~data:() in
    assert_some (Route.match_route route "/users/profile")
  );
  
  test "parse param segment" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() in
    assert_some (Route.match_route route "/users/123")
  );
  
  test "parse wildcard" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() in
    assert_some (Route.match_route route "/files/a/b/c")
  )

(* ========== Static Route Matching ========== *)

let test_static_matching () =
  print_endline "\n=== Static Route Matching ===";
  
  test "exact match succeeds" (fun () ->
    let route = Route.create ~path:"/users" ~data:() in
    assert_some (Route.match_route route "/users")
  );
  
  test "exact match with trailing slash" (fun () ->
    let route = Route.create ~path:"/users" ~data:() in
    assert_some (Route.match_route route "/users/")
  );
  
  test "different path fails" (fun () ->
    let route = Route.create ~path:"/users" ~data:() in
    assert_none (Route.match_route route "/posts")
  );
  
  test "prefix match fails" (fun () ->
    let route = Route.create ~path:"/users" ~data:() in
    assert_none (Route.match_route route "/users/123")
  );
  
  test "multi-segment exact match" (fun () ->
    let route = Route.create ~path:"/api/v1/users" ~data:() in
    assert_some (Route.match_route route "/api/v1/users")
  );
  
  test "multi-segment partial fails" (fun () ->
    let route = Route.create ~path:"/api/v1/users" ~data:() in
    assert_none (Route.match_route route "/api/v1")
  )

(* ========== Parameter Matching ========== *)

let test_param_matching () =
  print_endline "\n=== Parameter Matching ===";
  
  test "single param extraction" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() in
    match Route.match_route route "/users/123" with
    | Some result ->
      assert_equal (Route.Params.get "id" result.params) (Some "123")
    | None -> failwith "expected match"
  );
  
  test "multiple params extraction" (fun () ->
    let route = Route.create ~path:"/users/:user_id/posts/:post_id" ~data:() in
    match Route.match_route route "/users/42/posts/99" with
    | Some result ->
      assert_equal (Route.Params.get "user_id" result.params) (Some "42");
      assert_equal (Route.Params.get "post_id" result.params) (Some "99")
    | None -> failwith "expected match"
  );
  
  test "param with static prefix" (fun () ->
    let route = Route.create ~path:"/api/users/:id" ~data:() in
    match Route.match_route route "/api/users/abc" with
    | Some result ->
      assert_equal (Route.Params.get "id" result.params) (Some "abc")
    | None -> failwith "expected match"
  );
  
  test "param with static suffix" (fun () ->
    let route = Route.create ~path:"/:category/items" ~data:() in
    match Route.match_route route "/books/items" with
    | Some result ->
      assert_equal (Route.Params.get "category" result.params) (Some "books")
    | None -> failwith "expected match"
  );
  
  test "missing param segment fails" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() in
    assert_none (Route.match_route route "/users/")
  )

(* ========== Wildcard Matching ========== *)

let test_wildcard_matching () =
  print_endline "\n=== Wildcard Matching ===";
  
  test "wildcard captures single segment" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() in
    match Route.match_route route "/files/readme.txt" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "readme.txt")
    | None -> failwith "expected match"
  );
  
  test "wildcard captures multiple segments" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() in
    match Route.match_route route "/files/path/to/file.txt" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "path/to/file.txt")
    | None -> failwith "expected match"
  );
  
  test "wildcard captures empty" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() in
    match Route.match_route route "/files/" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "")
    | None -> failwith "expected match"
  );
  
  test "static before wildcard" (fun () ->
    let route = Route.create ~path:"/api/files/*" ~data:() in
    assert_some (Route.match_route route "/api/files/a/b");
    assert_none (Route.match_route route "/other/files/a/b")
  )

(* ========== Route List Matching ========== *)

let test_route_list_matching () =
  print_endline "\n=== Route List Matching ===";
  
  let routes = [
    Route.create ~path:"/" ~data:"home";
    Route.create ~path:"/users" ~data:"users_list";
    Route.create ~path:"/users/:id" ~data:"user_detail";
    Route.create ~path:"/posts/*" ~data:"posts_catchall";
  ] in
  
  test "match root" (fun () ->
    match Route.match_routes routes "/" with
    | Some (route, _) -> assert_equal (Route.data route) "home"
    | None -> failwith "expected match"
  );
  
  test "match static" (fun () ->
    match Route.match_routes routes "/users" with
    | Some (route, _) -> assert_equal (Route.data route) "users_list"
    | None -> failwith "expected match"
  );
  
  test "match param" (fun () ->
    match Route.match_routes routes "/users/123" with
    | Some (route, result) ->
      assert_equal (Route.data route) "user_detail";
      assert_equal (Route.Params.get "id" result.params) (Some "123")
    | None -> failwith "expected match"
  );
  
  test "match wildcard" (fun () ->
    match Route.match_routes routes "/posts/2024/01/hello" with
    | Some (route, result) ->
      assert_equal (Route.data route) "posts_catchall";
      assert_equal (Route.Params.get "*" result.params) (Some "2024/01/hello")
    | None -> failwith "expected match"
  );
  
  test "no match returns None" (fun () ->
    assert_none (Route.match_routes routes "/unknown")
  );
  
  test "first match wins" (fun () ->
    (* /users matches before /users/:id because it's first in list *)
    match Route.match_routes routes "/users" with
    | Some (route, _) -> assert_equal (Route.data route) "users_list"
    | None -> failwith "expected match"
  )

(* ========== Path Generation ========== *)

let test_path_generation () =
  print_endline "\n=== Path Generation ===";
  
  test "generate static path" (fun () ->
    let path = Route.generate_path "/users" [] in
    assert_equal path "/users"
  );
  
  test "generate path with param" (fun () ->
    let path = Route.generate_path "/users/:id" [("id", "123")] in
    assert_equal path "/users/123"
  );
  
  test "generate path with multiple params" (fun () ->
    let path = Route.generate_path "/users/:user_id/posts/:post_id" 
      [("user_id", "42"); ("post_id", "99")] in
    assert_equal path "/users/42/posts/99"
  );
  
  test "missing param keeps placeholder" (fun () ->
    let path = Route.generate_path "/users/:id" [] in
    assert_equal path "/users/:id"
  )

(* ========== Params Module ========== *)

let test_params () =
  print_endline "\n=== Params Module ===";
  
  test "empty params" (fun () ->
    let p = Route.Params.empty in
    assert_none (Route.Params.get "foo" p)
  );
  
  test "get existing param" (fun () ->
    let p = Route.Params.of_list [("foo", "bar")] in
    assert_equal (Route.Params.get "foo" p) (Some "bar")
  );
  
  test "get_exn existing param" (fun () ->
    let p = Route.Params.of_list [("foo", "bar")] in
    assert_equal (Route.Params.get_exn "foo" p) "bar"
  );
  
  test "get_exn missing param raises" (fun () ->
    let p = Route.Params.empty in
    try
      let _ = Route.Params.get_exn "foo" p in
      failwith "should have raised"
    with Not_found -> ()
  );
  
  test "add and get param" (fun () ->
    let p = Route.Params.empty |> Route.Params.add "x" "1" in
    assert_equal (Route.Params.get "x" p) (Some "1")
  );
  
  test "to_list preserves params" (fun () ->
    let p = Route.Params.of_list [("a", "1"); ("b", "2")] in
    let lst = Route.Params.to_list p in
    assert_equal (List.length lst) 2
  )

(* ========== Run All Tests ========== *)

let () =
  print_endline "\n==============================";
  print_endline "  Router Tests";
  print_endline "==============================";
  
  test_pattern_parsing ();
  test_static_matching ();
  test_param_matching ();
  test_wildcard_matching ();
  test_route_list_matching ();
  test_path_generation ();
  test_params ();
  
  print_endline "\n==============================";
  Printf.printf "  Results: %d passed, %d failed\n" !passed !failed;
  print_endline "==============================\n";
  
  if !failed > 0 then exit 1

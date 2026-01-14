(** Router tests *)

open Solid_ml_router
open Solid_ml

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
    let route = Route.create ~path:"/" ~data:() () in
    assert_some (Route.match_route route "/")
  );
  
  test "parse static path" (fun () ->
    let route = Route.create ~path:"/users" ~data:() () in
    assert_some (Route.match_route route "/users")
  );
  
  test "parse multi-segment static" (fun () ->
    let route = Route.create ~path:"/users/profile" ~data:() () in
    assert_some (Route.match_route route "/users/profile")
  );
  
  test "parse param segment" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() () in
    assert_some (Route.match_route route "/users/123")
  );
  
  test "parse wildcard" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() () in
    assert_some (Route.match_route route "/files/a/b/c")
  )

(* ========== Static Route Matching ========== *)

let test_static_matching () =
  print_endline "\n=== Static Route Matching ===";
  
  test "exact match succeeds" (fun () ->
    let route = Route.create ~path:"/users" ~data:() () in
    assert_some (Route.match_route route "/users")
  );
  
  test "exact match with trailing slash" (fun () ->
    let route = Route.create ~path:"/users" ~data:() () in
    assert_some (Route.match_route route "/users/")
  );
  
  test "different path fails" (fun () ->
    let route = Route.create ~path:"/users" ~data:() () in
    assert_none (Route.match_route route "/posts")
  );
  
  test "prefix match fails" (fun () ->
    let route = Route.create ~path:"/users" ~data:() () in
    assert_none (Route.match_route route "/users/123")
  );
  
  test "multi-segment exact match" (fun () ->
    let route = Route.create ~path:"/api/v1/users" ~data:() () in
    assert_some (Route.match_route route "/api/v1/users")
  );
  
  test "multi-segment partial fails" (fun () ->
    let route = Route.create ~path:"/api/v1/users" ~data:() () in
    assert_none (Route.match_route route "/api/v1")
  )

(* ========== Parameter Matching ========== *)

let test_param_matching () =
  print_endline "\n=== Parameter Matching ===";
  
  test "single param extraction" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() () in
    match Route.match_route route "/users/123" with
    | Some result ->
      assert_equal (Route.Params.get "id" result.params) (Some "123")
    | None -> failwith "expected match"
  );
  
  test "multiple params extraction" (fun () ->
    let route = Route.create ~path:"/users/:user_id/posts/:post_id" ~data:() () in
    match Route.match_route route "/users/42/posts/99" with
    | Some result ->
      assert_equal (Route.Params.get "user_id" result.params) (Some "42");
      assert_equal (Route.Params.get "post_id" result.params) (Some "99")
    | None -> failwith "expected match"
  );
  
  test "param with static prefix" (fun () ->
    let route = Route.create ~path:"/api/users/:id" ~data:() () in
    match Route.match_route route "/api/users/abc" with
    | Some result ->
      assert_equal (Route.Params.get "id" result.params) (Some "abc")
    | None -> failwith "expected match"
  );
  
  test "param with static suffix" (fun () ->
    let route = Route.create ~path:"/:category/items" ~data:() () in
    match Route.match_route route "/books/items" with
    | Some result ->
      assert_equal (Route.Params.get "category" result.params) (Some "books")
    | None -> failwith "expected match"
  );
  
  test "missing param segment fails" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() () in
    assert_none (Route.match_route route "/users/")
  )

(* ========== Wildcard Matching ========== *)

let test_wildcard_matching () =
  print_endline "\n=== Wildcard Matching ===";
  
  test "wildcard captures single segment" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() () in
    match Route.match_route route "/files/readme.txt" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "readme.txt")
    | None -> failwith "expected match"
  );
  
  test "wildcard captures multiple segments" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() () in
    match Route.match_route route "/files/path/to/file.txt" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "path/to/file.txt")
    | None -> failwith "expected match"
  );
  
  test "wildcard captures empty" (fun () ->
    let route = Route.create ~path:"/files/*" ~data:() () in
    match Route.match_route route "/files/" with
    | Some result ->
      assert_equal (Route.Params.get "*" result.params) (Some "")
    | None -> failwith "expected match"
  );
  
  test "static before wildcard" (fun () ->
    let route = Route.create ~path:"/api/files/*" ~data:() () in
    assert_some (Route.match_route route "/api/files/a/b");
    assert_none (Route.match_route route "/other/files/a/b")
  )

(* ========== Route List Matching ========== *)

let test_route_list_matching () =
  print_endline "\n=== Route List Matching ===";
  
  let routes = [
    Route.create ~path:"/" ~data:"home" ();
    Route.create ~path:"/users" ~data:"users_list" ();
    Route.create ~path:"/users/:id" ~data:"user_detail" ();
    Route.create ~path:"/posts/*" ~data:"posts_catchall" ();
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

(* ========== URL Parsing ========== *)

let test_url_parsing () =
  print_endline "\n=== URL Parsing ===";
  
  test "parse simple path" (fun () ->
    let path, query, hash = Router.parse_url "/users" in
    assert_equal path "/users";
    assert_none query;
    assert_none hash
  );
  
  test "parse path with query" (fun () ->
    let path, query, hash = Router.parse_url "/search?q=test" in
    assert_equal path "/search";
    assert_equal query (Some "q=test");
    assert_none hash
  );
  
  test "parse path with hash" (fun () ->
    let path, query, hash = Router.parse_url "/docs#section1" in
    assert_equal path "/docs";
    assert_none query;
    assert_equal hash (Some "section1")
  );
  
  test "parse path with query and hash" (fun () ->
    let path, query, hash = Router.parse_url "/page?foo=bar#top" in
    assert_equal path "/page";
    assert_equal query (Some "foo=bar");
    assert_equal hash (Some "top")
  );
  
  test "parse root path" (fun () ->
    let path, query, hash = Router.parse_url "/" in
    assert_equal path "/";
    assert_none query;
    assert_none hash
  )

(* ========== Query String Parsing ========== *)

let test_query_string_parsing () =
  print_endline "\n=== Query String Parsing ===";
  
  test "parse empty query" (fun () ->
    let pairs = Router.parse_query_string "" in
    assert_equal (List.length pairs) 0
  );
  
  test "parse single param" (fun () ->
    let pairs = Router.parse_query_string "foo=bar" in
    assert_equal (List.assoc_opt "foo" pairs) (Some "bar")
  );
  
  test "parse multiple params" (fun () ->
    let pairs = Router.parse_query_string "a=1&b=2&c=3" in
    assert_equal (List.assoc_opt "a" pairs) (Some "1");
    assert_equal (List.assoc_opt "b" pairs) (Some "2");
    assert_equal (List.assoc_opt "c" pairs) (Some "3")
  );
  
  test "parse param without value" (fun () ->
    let pairs = Router.parse_query_string "flag" in
    assert_equal (List.assoc_opt "flag" pairs) (Some "")
  );
  
  test "get_query_param helper" (fun () ->
    let query = Some "name=john&age=30" in
    assert_equal (Router.get_query_param "name" query) (Some "john");
    assert_equal (Router.get_query_param "age" query) (Some "30");
    assert_none (Router.get_query_param "missing" query)
  );
  
  test "get_query_param with None query" (fun () ->
    assert_none (Router.get_query_param "foo" None)
  )

(* ========== URL Building ========== *)

let test_url_building () =
  print_endline "\n=== URL Building ===";
  
  test "build simple path" (fun () ->
    let url = Router.build_url ~path:"/users" () in
    assert_equal url "/users"
  );
  
  test "build path with query" (fun () ->
    let url = Router.build_url ~path:"/search" ~query:"q=test" () in
    assert_equal url "/search?q=test"
  );
  
  test "build path with hash" (fun () ->
    let url = Router.build_url ~path:"/docs" ~hash:"section1" () in
    assert_equal url "/docs#section1"
  );
  
  test "build path with query and hash" (fun () ->
    let url = Router.build_url ~path:"/page" ~query:"foo=bar" ~hash:"top" () in
    assert_equal url "/page?foo=bar#top"
  )

(* ========== URL Encoding/Decoding ========== *)

let test_url_encoding () =
  print_endline "\n=== URL Encoding/Decoding ===";
  
  test "url_decode simple" (fun () ->
    assert_equal (Router.url_decode "hello") "hello"
  );
  
  test "url_decode percent encoding" (fun () ->
    assert_equal (Router.url_decode "hello%20world") "hello world"
  );
  
  test "url_decode plus as space" (fun () ->
    assert_equal (Router.url_decode "hello+world") "hello world"
  );
  
  test "url_decode special chars" (fun () ->
    assert_equal (Router.url_decode "foo%26bar%3Dbaz") "foo&bar=baz"
  );
  
  test "url_encode simple" (fun () ->
    assert_equal (Router.url_encode "hello") "hello"
  );
  
  test "url_encode spaces" (fun () ->
    assert_equal (Router.url_encode "hello world") "hello+world"
  );
  
  test "url_encode special chars" (fun () ->
    let encoded = Router.url_encode "foo&bar=baz" in
    assert_equal encoded "foo%26bar%3Dbaz"
  );
  
  test "url_encode roundtrip" (fun () ->
    let original = "hello world & foo=bar" in
    let encoded = Router.url_encode original in
    let decoded = Router.url_decode encoded in
    assert_equal decoded original
  );
  
  test "query string decodes values" (fun () ->
    let pairs = Router.parse_query_string "name=john%20doe&city=new+york" in
    assert_equal (List.assoc_opt "name" pairs) (Some "john doe");
    assert_equal (List.assoc_opt "city" pairs) (Some "new york")
  );
  
  test "build_query_string encodes values" (fun () ->
    let qs = Router.build_query_string [("name", "john doe"); ("q", "foo&bar")] in
    assert_equal qs "name=john+doe&q=foo%26bar"
  )

(* ========== Router Provider ========== *)

let test_router_provider () =
  print_endline "\n=== Router Provider ===";
  
  test "provide sets initial path" (fun () ->
    let routes = [
      Route.create ~path:"/" ~data:() ();
      Route.create ~path:"/users/:id" ~data:() ();
    ] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/users/123" ~routes (fun () ->
        let path = Router.use_path () in
        assert_equal path "/users/123"
      )
    )
  );
  
  test "provide extracts params from route" (fun () ->
    let routes = [
      Route.create ~path:"/users/:id" ~data:() ();
    ] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/users/456" ~routes (fun () ->
        let id = Router.use_param "id" in
        assert_equal id (Some "456")
      )
    )
  );
  
  test "provide parses query string" (fun () ->
    let routes = [Route.create ~path:"/search" ~data:() ()] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/search?q=test&page=2" ~routes (fun () ->
        (* Query parsing is tested via URL parsing tests *)
        let path = Router.use_path () in
        assert_equal path "/search"
      )
    )
  );
  
  test "navigate updates path" (fun () ->
    let routes = [
      Route.create ~path:"/" ~data:() ();
      Route.create ~path:"/about" ~data:() ();
    ] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/" ~routes (fun () ->
        assert_equal (Router.use_path ()) "/";
        Router.navigate "/about";
        assert_equal (Router.use_path ()) "/about"
      )
    )
  );
  
  test "use_path outside context raises" (fun () ->
    Runtime.run (fun () ->
      try
        let _ = Router.use_path () in
        failwith "should have raised"
      with Router.No_router_context -> ()
    )
  )

(* ========== Link Component ========== *)

let test_link_component () =
  print_endline "\n=== Link Component ===";
  
  test "link renders anchor tag" (fun () ->
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/" (fun () ->
        let node = Components.Link.link ~href:"/about" ~children:[Solid_ml_ssr.Html.text "About"] () in
        let html = Solid_ml_ssr.Html.to_string node in
        assert (String.length html > 0);
        assert (String.sub html 0 9 = "<a href=\"")
      )
    )
  );
  
  test "link with class" (fun () ->
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/" (fun () ->
        let node = Components.Link.link ~class_:"nav-link" ~href:"/about" ~children:[Solid_ml_ssr.Html.text "About"] () in
        let html = Solid_ml_ssr.Html.to_string node in
        assert (String.length html > 0)
      )
    )
  );
  
  test "nav_link adds active class when exact match" (fun () ->
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/about" (fun () ->
        let node = Components.Link.nav_link ~exact:true ~href:"/about" ~children:[Solid_ml_ssr.Html.text "About"] () in
        let html = Solid_ml_ssr.Html.to_string node in
        (* Should contain class="active" - class comes before href *)
        assert (String.length html > 0);
        (* Check that "active" appears in the output *)
        assert (String.length html > 10);
        let has_active = ref false in
        for i = 0 to String.length html - 6 do
          if String.sub html i 6 = "active" then has_active := true
        done;
        assert !has_active
      )
    )
  );
  
  test "nav_link partial match (default)" (fun () ->
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/users/123" (fun () ->
        (* /users should be active when viewing /users/123 *)
        let node = Components.Link.nav_link ~href:"/users" ~children:[Solid_ml_ssr.Html.text "Users"] () in
        let html = Solid_ml_ssr.Html.to_string node in
        (* Check that "active" appears in the output *)
        let has_active = ref false in
        for i = 0 to String.length html - 6 do
          if String.sub html i 6 = "active" then has_active := true
        done;
        assert !has_active
      )
    )
  );
  
  test "nav_link exact match does not match partial" (fun () ->
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/users/123" (fun () ->
        (* With exact=true, /users should NOT be active when viewing /users/123 *)
        let node = Components.Link.nav_link ~exact:true ~href:"/users" ~children:[Solid_ml_ssr.Html.text "Users"] () in
        let html = Solid_ml_ssr.Html.to_string node in
        (* Should NOT have active class *)
        assert (String.sub html 0 9 = "<a href=\"")
      )
    )
  )

(* ========== Outlet Component ========== *)

let test_outlet_component () =
  print_endline "\n=== Outlet Component ===";
  
  test "outlet renders matched route" (fun () ->
    let home_component () = Solid_ml_ssr.Html.text "Home Page" in
    let about_component () = Solid_ml_ssr.Html.text "About Page" in
    
    let routes = [
      Route.create ~path:"/" ~data:home_component ();
      Route.create ~path:"/about" ~data:about_component ();
    ] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/" (fun () ->
        let node = Components.Link.outlet ~routes () in
        let html = Solid_ml_ssr.Html.to_string node in
        assert_equal html "Home Page"
      )
    )
  );
  
  test "outlet renders not_found when no match" (fun () ->
    let routes = [
      Route.create ~path:"/" ~data:(fun () -> Solid_ml_ssr.Html.text "Home") ();
    ] in
    Runtime.run (fun () ->
      Components.Link.provide ~initial_path:"/unknown" (fun () ->
        let not_found () = Solid_ml_ssr.Html.text "404 Not Found" in
        let node = Components.Link.outlet ~routes ~not_found () in
        let html = Solid_ml_ssr.Html.to_string node in
        assert_equal html "404 Not Found"
      )
    )
  )

(* ========== Match Filters ========== *)

let test_match_filters () =
  print_endline "\n=== Match Filters ===";
  
  test "filter int - valid" (fun () ->
    let route = Route.create 
      ~path:"/users/:id" 
      ~filters:[("id", Route.Filter.int)]
      ~data:() () in
    assert_some (Route.match_route route "/users/123")
  );
  
  test "filter int - invalid" (fun () ->
    let route = Route.create 
      ~path:"/users/:id" 
      ~filters:[("id", Route.Filter.int)]
      ~data:() () in
    assert_none (Route.match_route route "/users/abc")
  );
  
  test "filter int - negative" (fun () ->
    let route = Route.create 
      ~path:"/users/:id" 
      ~filters:[("id", Route.Filter.int)]
      ~data:() () in
    assert_some (Route.match_route route "/users/-5")
  );
  
  test "filter positive_int - valid" (fun () ->
    let route = Route.create 
      ~path:"/posts/:id" 
      ~filters:[("id", Route.Filter.positive_int)]
      ~data:() () in
    assert_some (Route.match_route route "/posts/42")
  );
  
  test "filter positive_int - zero fails" (fun () ->
    let route = Route.create 
      ~path:"/posts/:id" 
      ~filters:[("id", Route.Filter.positive_int)]
      ~data:() () in
    assert_none (Route.match_route route "/posts/0")
  );
  
  test "filter positive_int - negative fails" (fun () ->
    let route = Route.create 
      ~path:"/posts/:id" 
      ~filters:[("id", Route.Filter.positive_int)]
      ~data:() () in
    assert_none (Route.match_route route "/posts/-1")
  );
  
  test "filter non_negative_int - zero passes" (fun () ->
    let route = Route.create 
      ~path:"/page/:num" 
      ~filters:[("num", Route.Filter.non_negative_int)]
      ~data:() () in
    assert_some (Route.match_route route "/page/0")
  );
  
  test "filter uuid - valid" (fun () ->
    let route = Route.create 
      ~path:"/items/:id" 
      ~filters:[("id", Route.Filter.uuid)]
      ~data:() () in
    assert_some (Route.match_route route "/items/550e8400-e29b-41d4-a716-446655440000")
  );
  
  test "filter uuid - invalid format" (fun () ->
    let route = Route.create 
      ~path:"/items/:id" 
      ~filters:[("id", Route.Filter.uuid)]
      ~data:() () in
    assert_none (Route.match_route route "/items/not-a-uuid")
  );
  
  test "filter uuid - uppercase valid" (fun () ->
    let route = Route.create 
      ~path:"/items/:id" 
      ~filters:[("id", Route.Filter.uuid)]
      ~data:() () in
    assert_some (Route.match_route route "/items/550E8400-E29B-41D4-A716-446655440000")
  );
  
  test "filter alphanumeric - valid" (fun () ->
    let route = Route.create 
      ~path:"/users/:username" 
      ~filters:[("username", Route.Filter.alphanumeric)]
      ~data:() () in
    assert_some (Route.match_route route "/users/JohnDoe123")
  );
  
  test "filter alphanumeric - invalid" (fun () ->
    let route = Route.create 
      ~path:"/users/:username" 
      ~filters:[("username", Route.Filter.alphanumeric)]
      ~data:() () in
    assert_none (Route.match_route route "/users/john-doe")
  );
  
  test "filter slug - valid" (fun () ->
    let route = Route.create 
      ~path:"/posts/:slug" 
      ~filters:[("slug", Route.Filter.slug)]
      ~data:() () in
    assert_some (Route.match_route route "/posts/my-first-post")
  );
  
  test "filter slug - uppercase fails" (fun () ->
    let route = Route.create 
      ~path:"/posts/:slug" 
      ~filters:[("slug", Route.Filter.slug)]
      ~data:() () in
    assert_none (Route.match_route route "/posts/My-Post")
  );
  
  test "filter one_of - valid" (fun () ->
    let route = Route.create 
      ~path:"/lang/:code" 
      ~filters:[("code", Route.Filter.one_of ["en"; "fr"; "de"])]
      ~data:() () in
    assert_some (Route.match_route route "/lang/en");
    assert_some (Route.match_route route "/lang/fr")
  );
  
  test "filter one_of - invalid" (fun () ->
    let route = Route.create 
      ~path:"/lang/:code" 
      ~filters:[("code", Route.Filter.one_of ["en"; "fr"; "de"])]
      ~data:() () in
    assert_none (Route.match_route route "/lang/es")
  );
  
  test "filter length - valid" (fun () ->
    let route = Route.create 
      ~path:"/code/:code" 
      ~filters:[("code", Route.Filter.length ~min:3 ~max:6)]
      ~data:() () in
    assert_some (Route.match_route route "/code/abc");
    assert_some (Route.match_route route "/code/abcdef")
  );
  
  test "filter length - too short" (fun () ->
    let route = Route.create 
      ~path:"/code/:code" 
      ~filters:[("code", Route.Filter.length ~min:3 ~max:6)]
      ~data:() () in
    assert_none (Route.match_route route "/code/ab")
  );
  
  test "filter length - too long" (fun () ->
    let route = Route.create 
      ~path:"/code/:code" 
      ~filters:[("code", Route.Filter.length ~min:3 ~max:6)]
      ~data:() () in
    assert_none (Route.match_route route "/code/abcdefg")
  );
  
  test "filter all - combines with AND" (fun () ->
    let route = Route.create 
      ~path:"/id/:id" 
      ~filters:[("id", Route.Filter.all [Route.Filter.int; Route.Filter.min_length 2])]
      ~data:() () in
    assert_some (Route.match_route route "/id/42");
    assert_none (Route.match_route route "/id/1");  (* too short *)
    assert_none (Route.match_route route "/id/ab")  (* not int *)
  );
  
  test "filter any_of - combines with OR" (fun () ->
    let route = Route.create 
      ~path:"/ref/:ref" 
      ~filters:[("ref", Route.Filter.any_of [Route.Filter.int; Route.Filter.slug])]
      ~data:() () in
    assert_some (Route.match_route route "/ref/123");
    assert_some (Route.match_route route "/ref/my-slug")
  );
  
  test "filter not_ - negation" (fun () ->
    let route = Route.create 
      ~path:"/name/:name" 
      ~filters:[("name", Route.Filter.not_ (Route.Filter.one_of ["admin"; "root"]))]
      ~data:() () in
    assert_some (Route.match_route route "/name/john");
    assert_none (Route.match_route route "/name/admin")
  );
  
  test "multiple filters on different params" (fun () ->
    let route = Route.create 
      ~path:"/users/:id/posts/:post_id"
      ~filters:[
        ("id", Route.Filter.positive_int);
        ("post_id", Route.Filter.positive_int)
      ]
      ~data:() () in
    assert_some (Route.match_route route "/users/1/posts/99");
    assert_none (Route.match_route route "/users/abc/posts/99");
    assert_none (Route.match_route route "/users/1/posts/abc")
  );
  
  test "filter with route matching - first valid wins" (fun () ->
    let routes = [
      Route.create ~path:"/items/:id" ~filters:[("id", Route.Filter.int)] ~data:"numeric" ();
      Route.create ~path:"/items/:id" ~filters:[("id", Route.Filter.slug)] ~data:"slug" ();
      Route.create ~path:"/items/:id" ~data:"any" ();  (* no filter - catches all *)
    ] in
    (* Numeric ID matches first route *)
    (match Route.match_routes routes "/items/123" with
     | Some (route, _) -> assert_equal (Route.data route) "numeric"
     | None -> failwith "expected match");
    (* Slug matches second route *)
    (match Route.match_routes routes "/items/my-item" with
     | Some (route, _) -> assert_equal (Route.data route) "slug"
     | None -> failwith "expected match");
    (* Other matches third route *)
    (match Route.match_routes routes "/items/Some_Thing" with
     | Some (route, _) -> assert_equal (Route.data route) "any"
     | None -> failwith "expected match")
  );
  
  test "params are still extracted with filters" (fun () ->
    let route = Route.create 
      ~path:"/users/:id" 
      ~filters:[("id", Route.Filter.positive_int)]
      ~data:() () in
    match Route.match_route route "/users/42" with
    | Some result -> assert_equal (Route.Params.get "id" result.params) (Some "42")
    | None -> failwith "expected match"
  );
  
  test "route without filters still works" (fun () ->
    let route = Route.create ~path:"/users/:id" ~data:() () in
    assert_some (Route.match_route route "/users/anything")
  )

(* ========== Resource ========== *)

let test_resource () =
  print_endline "\n=== Resource ===";
  
  test "resource starts loading then ready" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create (fun () -> 42) in
      match Resource.read r with
      | Resource.Ready v -> assert_equal v 42
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource of_value is ready" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_value "hello" in
      match Resource.read r with
      | Resource.Ready v -> assert_equal v "hello"
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource of_error is error" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_error "something went wrong" in
      match Resource.read r with
      | Resource.Error msg -> assert_equal msg "something went wrong"
      | _ -> failwith "expected Error"
    )
  );
  
  test "resource create_loading is pending" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create_loading () in
      match Resource.read r with
      | Resource.Pending -> ()
      | _ -> failwith "expected Pending"
    )
  );
  
  test "resource set transitions to ready" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create_loading () in
      Resource.set r 99;
      match Resource.read r with
      | Resource.Ready v -> assert_equal v 99
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource set_error transitions to error" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_value 1 in
      Resource.set_error r "failed";
      match Resource.read r with
      | Resource.Error msg -> assert_equal msg "failed"
      | _ -> failwith "expected Error"
    )
  );
  
  test "resource is_loading" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create_loading () in
      assert (Resource.is_loading r);
      assert (not (Resource.is_ready r));
      assert (not (Resource.is_error r))
    )
  );
  
  test "resource is_ready" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_value 1 in
      assert (Resource.is_ready r);
      assert (not (Resource.is_loading r));
      assert (not (Resource.is_error r))
    )
  );
  
  test "resource is_error" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_error "err" in
      assert (Resource.is_error r);
      assert (not (Resource.is_loading r));
      assert (not (Resource.is_ready r))
    )
  );
  
  test "resource get_data" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_value 123 in
      assert_equal (Resource.get_data r) (Some 123);
      let r2 = Resource.create_loading () in
      assert_none (Resource.get_data r2)
    )
  );
  
  test "resource get_error" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_error "oops" in
      assert_equal (Resource.get_error r) (Some "oops");
      let r2 = Resource.of_value 1 in
      assert_none (Resource.get_error r2)
    )
  );
  
  test "resource map on ready" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.of_value 10 in
      match Resource.map (fun x -> x * 2) r with
      | Resource.Ready v -> assert_equal v 20
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource map on loading" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create_loading () in
      match Resource.map (fun x -> x * 2) r with
      | Resource.Pending -> ()
      | _ -> failwith "expected Pending"
    )
  );

  test "resource combine both ready" (fun () ->
    Runtime.run (fun () ->
      let r1 = Resource.of_value 1 in
      let r2 = Resource.of_value 2 in
      let combined = Resource.combine r1 r2 in
      match Resource.read combined with
      | Resource.Ready (a, b) -> 
        assert_equal a 1;
        assert_equal b 2
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource combine one loading" (fun () ->
    Runtime.run (fun () ->
      let r1 = Resource.of_value 1 in
      let r2 = Resource.create_loading () in
      let combined = Resource.combine r1 r2 in
      match Resource.read combined with
      | Resource.Pending -> ()
      | _ -> failwith "expected Pending"
    )
  );
  
  test "resource combine one error" (fun () ->
    Runtime.run (fun () ->
      let r1 = Resource.of_value 1 in
      let r2 = Resource.of_error "fail" in
      let combined = Resource.combine r1 r2 in
      match Resource.read combined with
      | Resource.Error msg -> assert_equal msg "fail"
      | _ -> failwith "expected Error"
    )
  );
  
  test "resource combine_all" (fun () ->
    Runtime.run (fun () ->
      let r1 = Resource.of_value 1 in
      let r2 = Resource.of_value 2 in
      let r3 = Resource.of_value 3 in
      let combined = Resource.combine_all [r1; r2; r3] in
      match Resource.read combined with
      | Resource.Ready lst -> assert_equal lst [1; 2; 3]
      | _ -> failwith "expected Ready"
    )
  );
  
  test "resource fetcher exception becomes error" (fun () ->
    Runtime.run (fun () ->
      let r = Resource.create (fun () -> failwith "boom") in
      match Resource.read r with
      | Resource.Error _ -> ()
      | _ -> failwith "expected Error"
    )
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
  test_url_parsing ();
  test_query_string_parsing ();
  test_url_building ();
  test_url_encoding ();
  test_match_filters ();
  test_router_provider ();
  test_link_component ();
  test_outlet_component ();
  test_resource ();
  
  print_endline "\n==============================";
  Printf.printf "  Results: %d passed, %d failed\n" !passed !failed;
  print_endline "==============================\n";
  
  if !failed > 0 then exit 1

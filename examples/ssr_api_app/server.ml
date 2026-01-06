(** SSR API App Example - Server
    
    This example demonstrates a full SSR app that fetches data from a REST API:
    1. Server fetches data from JSONPlaceholder API
    2. Server renders HTML with the fetched data
    3. Client hydrates and enables SPA navigation with client-side fetching
    
    Run with: make example-ssr-api
    Then visit: http://localhost:8080
*)

open Solid_ml_html

(** {1 Data Types} *)

type post = {
  id : int;
  user_id : int;
  title : string;
  body : string;
}

type comment = {
  id : int;
  post_id : int;
  name : string;
  email : string;
  body : string;
}

(** {1 JSON Parsing} *)

let parse_post json =
  let open Yojson.Basic.Util in
  {
    id = json |> member "id" |> to_int;
    user_id = json |> member "userId" |> to_int;
    title = json |> member "title" |> to_string;
    body = json |> member "body" |> to_string;
  }

let parse_posts json =
  let open Yojson.Basic.Util in
  json |> to_list |> List.map parse_post

let parse_comment json =
  let open Yojson.Basic.Util in
  {
    id = json |> member "id" |> to_int;
    post_id = json |> member "postId" |> to_int;
    name = json |> member "name" |> to_string;
    email = json |> member "email" |> to_string;
    body = json |> member "body" |> to_string;
  }

let parse_comments json =
  let open Yojson.Basic.Util in
  json |> to_list |> List.map parse_comment

(** {1 API Client} *)

let api_base = "https://jsonplaceholder.typicode.com"

let fetch_json url =
  let open Lwt.Syntax in
  let uri = Uri.of_string url in
  let* resp, body = Cohttp_lwt_unix.Client.get uri in
  let status = Cohttp.Response.status resp in
  if Cohttp.Code.is_success (Cohttp.Code.code_of_status status) then
    let* body_str = Cohttp_lwt.Body.to_string body in
    Lwt.return_ok (Yojson.Basic.from_string body_str)
  else
    Lwt.return_error (Printf.sprintf "HTTP %d" (Cohttp.Code.code_of_status status))

let fetch_posts () =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/posts?_limit=10") in
  match result with
  | Ok json -> Lwt.return_ok (parse_posts json)
  | Error e -> Lwt.return_error e

let fetch_post id =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/posts/" ^ string_of_int id) in
  match result with
  | Ok json -> Lwt.return_ok (parse_post json)
  | Error e -> Lwt.return_error e

let fetch_comments post_id =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/posts/" ^ string_of_int post_id ^ "/comments") in
  match result with
  | Ok json -> Lwt.return_ok (parse_comments json)
  | Error e -> Lwt.return_error e

(** {1 Components} *)

(** Page layout with navigation *)
let layout ~title:page_title ~current_path ~children () =
  let nav_link href link_text =
    let is_active = current_path = href in
    Html.(
      a ~href 
        ~class_:(if is_active then "nav-link active" else "nav-link")
        ~children:[text link_text] ()
    )
  in
  
  Html.(
    html ~lang:"en" ~children:[
      head ~children:[
        meta ~charset:"utf-8" ();
        meta ~name:"viewport" ~content:"width=device-width, initial-scale=1" ();
        title ~children:[text page_title] ();
        raw {|<style>
          * { box-sizing: border-box; }
          body { 
            font-family: system-ui, -apple-system, sans-serif; 
            max-width: 900px; 
            margin: 0 auto; 
            padding: 20px;
            background: #f8f9fa;
            color: #333;
          }
          header { 
            background: white; 
            padding: 20px; 
            border-radius: 12px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
          }
          header h1 { margin: 0 0 16px 0; color: #2563eb; }
          nav { display: flex; gap: 8px; }
          .nav-link {
            padding: 8px 16px;
            text-decoration: none;
            color: #666;
            border-radius: 6px;
            transition: all 0.2s;
          }
          .nav-link:hover { background: #f0f0f0; color: #333; }
          .nav-link.active { background: #2563eb; color: white; }
          main {
            background: white;
            padding: 24px;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
          }
          .post-card {
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 12px;
            transition: all 0.2s;
          }
          .post-card:hover { 
            border-color: #2563eb;
            box-shadow: 0 2px 8px rgba(37,99,235,0.1);
          }
          .post-card h3 { margin: 0 0 8px 0; }
          .post-card h3 a { 
            color: #1f2937; 
            text-decoration: none;
          }
          .post-card h3 a:hover { color: #2563eb; }
          .post-card p { 
            color: #6b7280; 
            margin: 0;
            line-height: 1.5;
          }
          .post-card .meta { 
            font-size: 12px; 
            color: #9ca3af;
            margin-top: 8px;
          }
          .post-detail h2 { margin-top: 0; color: #1f2937; }
          .post-detail .body { 
            line-height: 1.7; 
            color: #4b5563;
            white-space: pre-wrap;
          }
          .post-detail .meta {
            font-size: 14px;
            color: #9ca3af;
            margin-bottom: 24px;
          }
          .comments { margin-top: 32px; }
          .comments h3 { 
            color: #1f2937;
            border-bottom: 2px solid #e5e7eb;
            padding-bottom: 8px;
          }
          .comment {
            background: #f9fafb;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 12px;
          }
          .comment .author { 
            font-weight: 600; 
            color: #1f2937;
            margin-bottom: 4px;
          }
          .comment .email { 
            font-size: 12px; 
            color: #9ca3af;
            margin-bottom: 8px;
          }
          .comment .body { 
            color: #4b5563;
            line-height: 1.5;
          }
          .back-link {
            display: inline-block;
            color: #2563eb;
            text-decoration: none;
            margin-bottom: 16px;
          }
          .back-link:hover { text-decoration: underline; }
          .loading {
            text-align: center;
            padding: 40px;
            color: #9ca3af;
          }
          .error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #dc2626;
            padding: 16px;
            border-radius: 8px;
          }
          footer {
            text-align: center;
            padding: 20px;
            color: #9ca3af;
            font-size: 14px;
          }
          footer a { color: #2563eb; }
          .hydration-status {
            padding: 8px 16px;
            background: #ecfdf5;
            border-radius: 6px;
            color: #059669;
            margin-top: 20px;
            display: none;
            font-size: 14px;
          }
          .hydration-status.active { display: block; }
        </style>|};
      ] ();
      body ~children:[
        header ~children:[
          h1 ~children:[text "Posts Viewer"] ();
          p ~class_:"subtitle" ~children:[
            text "SSR + API fetching demo"
          ] ();
          nav ~children:[
            nav_link "/" "All Posts";
          ] ();
        ] ();
        main ~id:"app" ~children ();
        footer ~children:[
          p ~children:[
            text "Data from ";
            a ~href:"https://jsonplaceholder.typicode.com" ~target:"_blank" 
              ~children:[text "JSONPlaceholder"] ();
            text " | Powered by ";
            a ~href:"https://github.com/makerprism/solid-ml" 
              ~children:[text "solid-ml"] ();
          ] ();
        ] ();
        (* Hydration script *)
        script ~src:"/static/client.js" ~type_:"module" ~children:[] ();
      ] ()
    ] ()
  )

(** Render a post card for the list view *)
let post_card (post : post) =
  Html.(
    div ~class_:"post-card" ~children:[
      h3 ~children:[
        a ~href:("/posts/" ^ string_of_int post.id) ~children:[
          text post.title
        ] ()
      ] ();
      p ~children:[
        text (String.sub post.body 0 (min 120 (String.length post.body)) ^ "...")
      ] ();
      div ~class_:"meta" ~children:[
        text ("Post #" ^ string_of_int post.id ^ " by User #" ^ string_of_int post.user_id)
      ] ();
    ] ()
  )

(** Render a comment *)
let comment_view (comment : comment) =
  Html.(
    div ~class_:"comment" ~children:[
      div ~class_:"author" ~children:[text comment.name] ();
      div ~class_:"email" ~children:[text comment.email] ();
      div ~class_:"body" ~children:[text comment.body] ();
    ] ()
  )

(** Home page - list of posts *)
let posts_page ~posts () =
  layout ~title:"Posts - solid-ml SSR API Demo" ~current_path:"/" ~children:(
    Html.[
      h2 ~children:[text "Recent Posts"] ();
      p ~children:[
        text "Click on a post to view details and comments."
      ] ();
      div ~id:"posts-list" ~children:(List.map post_card posts) ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Links now use client-side navigation."
      ] ();
    ]
  ) ()

(** Post detail page *)
let post_page ~post ~comments () =
  layout ~title:(post.title ^ " - solid-ml SSR API Demo") 
    ~current_path:("/posts/" ^ string_of_int post.id) ~children:(
    Html.[
      a ~href:"/" ~class_:"back-link" ~children:[text "← Back to all posts"] ();
      div ~class_:"post-detail" ~id:"post-detail" ~children:[
        h2 ~children:[text post.title] ();
        div ~class_:"meta" ~children:[
          text ("Post #" ^ string_of_int post.id ^ " by User #" ^ string_of_int post.user_id)
        ] ();
        div ~class_:"body" ~children:[text post.body] ();
      ] ();
      div ~class_:"comments" ~id:"comments-section" ~children:[
        h3 ~children:[
          text ("Comments (" ^ string_of_int (List.length comments) ^ ")")
        ] ();
        div ~id:"comments-list" ~children:(List.map comment_view comments) ();
      ] ();
      (* Store post ID for client-side use *)
      input ~type_:"hidden" ~id:"post-id" ~value:(string_of_int post.id) ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Navigation is now client-side."
      ] ();
    ]
  ) ()

(** Error page *)
let error_page ~message () =
  layout ~title:"Error - solid-ml SSR API Demo" ~current_path:"" ~children:(
    Html.[
      div ~class_:"error" ~children:[
        h2 ~children:[text "Error"] ();
        p ~children:[text message] ();
        p ~children:[
          a ~href:"/" ~children:[text "Go back home"] ()
        ] ();
      ] ();
    ]
  ) ()

(** 404 page *)
let not_found_page ~path () =
  layout ~title:"Not Found - solid-ml SSR API Demo" ~current_path:path ~children:(
    Html.[
      h2 ~children:[text "404 - Page Not Found"] ();
      p ~children:[
        text "The page ";
        code ~children:[text path] ();
        text " was not found.";
      ] ();
      p ~children:[
        a ~href:"/" ~children:[text "Go back home"] ()
      ] ();
    ]
  ) ()

(** {1 API Endpoints for Client-Side Fetching} *)

let handle_api_posts _req =
  let open Lwt.Syntax in
  let* result = fetch_posts () in
  match result with
  | Ok posts ->
    let json = `List (List.map (fun (p : post) ->
      `Assoc [
        ("id", `Int p.id);
        ("userId", `Int p.user_id);
        ("title", `String p.title);
        ("body", `String p.body);
      ]
    ) posts) in
    Dream.json (Yojson.Basic.to_string json)
  | Error e ->
    Dream.json ~status:`Internal_Server_Error 
      (Printf.sprintf {|{"error": "%s"}|} e)

let handle_api_post req =
  let open Lwt.Syntax in
  let id = Dream.param req "id" |> int_of_string in
  let* result = fetch_post id in
  match result with
  | Ok post ->
    let json = `Assoc [
      ("id", `Int post.id);
      ("userId", `Int post.user_id);
      ("title", `String post.title);
      ("body", `String post.body);
    ] in
    Dream.json (Yojson.Basic.to_string json)
  | Error e ->
    Dream.json ~status:`Internal_Server_Error 
      (Printf.sprintf {|{"error": "%s"}|} e)

let handle_api_comments req =
  let open Lwt.Syntax in
  let post_id = Dream.param req "id" |> int_of_string in
  let* result = fetch_comments post_id in
  match result with
  | Ok comments ->
    let json = `List (List.map (fun c ->
      `Assoc [
        ("id", `Int c.id);
        ("postId", `Int c.post_id);
        ("name", `String c.name);
        ("email", `String c.email);
        ("body", `String c.body);
      ]
    ) comments) in
    Dream.json (Yojson.Basic.to_string json)
  | Error e ->
    Dream.json ~status:`Internal_Server_Error 
      (Printf.sprintf {|{"error": "%s"}|} e)

(** {1 Page Handlers} *)

let handle_posts _req =
  let open Lwt.Syntax in
  let* result = fetch_posts () in
  match result with
  | Ok posts ->
    let html = Render.to_document (fun () -> posts_page ~posts ()) in
    Dream.html html
  | Error e ->
    let html = Render.to_document (fun () -> error_page ~message:e ()) in
    Dream.html ~status:`Internal_Server_Error html

let handle_post req =
  let open Lwt.Syntax in
  let id = 
    try Some (Dream.param req "id" |> int_of_string)
    with _ -> None
  in
  match id with
  | None ->
    let html = Render.to_document (fun () -> error_page ~message:"Invalid post ID" ()) in
    Dream.html ~status:`Bad_Request html
  | Some id ->
    let* post_result = fetch_post id in
    let* comments_result = fetch_comments id in
    match post_result, comments_result with
    | Ok post, Ok comments ->
      let html = Render.to_document (fun () -> post_page ~post ~comments ()) in
      Dream.html html
    | Error e, _ | _, Error e ->
      let html = Render.to_document (fun () -> error_page ~message:e ()) in
      Dream.html ~status:`Internal_Server_Error html

let handle_not_found req =
  let path = Dream.target req in
  let html = Render.to_document (fun () -> not_found_page ~path ()) in
  Dream.html ~status:`Not_Found html

(** {1 Main Server} *)

let () =
  let port = 
    match Sys.getenv_opt "PORT" with
    | Some p -> (try int_of_string p with _ -> 8080)
    | None -> 8080
  in
  
  Printf.printf "=== solid-ml SSR API Demo ===\n";
  Printf.printf "Server running at http://localhost:%d\n" port;
  Printf.printf "\n";
  Printf.printf "Pages:\n";
  Printf.printf "  http://localhost:%d/           - All posts\n" port;
  Printf.printf "  http://localhost:%d/posts/:id  - Post detail\n" port;
  Printf.printf "\n";
  Printf.printf "API Endpoints:\n";
  Printf.printf "  http://localhost:%d/api/posts        - List posts (JSON)\n" port;
  Printf.printf "  http://localhost:%d/api/posts/:id    - Get post (JSON)\n" port;
  Printf.printf "  http://localhost:%d/api/posts/:id/comments - Get comments (JSON)\n" port;
  Printf.printf "\n";
  Printf.printf "Press Ctrl+C to stop\n";
  flush stdout;
  
  Dream.run ~port
  @@ Dream.logger
  @@ Dream.router [
    (* API endpoints for client-side fetching *)
    Dream.get "/api/posts" handle_api_posts;
    Dream.get "/api/posts/:id" handle_api_post;
    Dream.get "/api/posts/:id/comments" handle_api_comments;
    (* HTML pages *)
    Dream.get "/" handle_posts;
    Dream.get "/posts/:id" handle_post;
    (* Static files *)
    Dream.get "/static/**" (Dream.static "examples/ssr_api_app/static");
    (* 404 fallback *)
    Dream.any "/**" handle_not_found;
  ]

(** SSR API App Example - Server
    
    This example demonstrates a full SSR app that fetches data from a REST API:
    1. Server fetches data from JSONPlaceholder API
    2. Server renders HTML with the fetched data
    3. Client hydrates and enables SPA navigation with client-side fetching
    
    Routes:
    - /           - All posts
    - /posts/:id  - Post detail with comments
    - /users      - All users
    - /users/:id  - User detail with their posts
    
    Run with: make example-ssr-api
    Then visit: http://localhost:8080
*)

open Solid_ml_ssr

module Shared = Ssr_api_shared.Components
module C = Shared.App (Solid_ml_ssr.Env)
module Routes = Ssr_api_shared.Routes

(** {1 Data Types} *)

type user = Shared.user
type post = Shared.post
type comment = Shared.comment

(** {1 JSON Parsing} *)

let parse_user json : user =
  let open Yojson.Basic.Util in
  let module S = Ssr_api_shared.Components in
  {
    S.id = json |> member "id" |> to_int;
    S.name = json |> member "name" |> to_string;
    S.username = json |> member "username" |> to_string;
    S.email = json |> member "email" |> to_string;
    S.phone = json |> member "phone" |> to_string;
    S.website = json |> member "website" |> to_string;
    S.company = json |> member "company" |> member "name" |> to_string;
    S.city = json |> member "address" |> member "city" |> to_string;
  }

let parse_users json =
  let open Yojson.Basic.Util in
  json |> to_list |> List.map parse_user

let parse_post json =
  let open Yojson.Basic.Util in
  let module S = Ssr_api_shared.Components in
  {
    S.id = json |> member "id" |> to_int;
    S.user_id = json |> member "userId" |> to_int;
    S.title = json |> member "title" |> to_string;
    S.body = json |> member "body" |> to_string;
  }

let parse_posts json =
  let open Yojson.Basic.Util in
  json |> to_list |> List.map parse_post

let parse_comment json =
  let open Yojson.Basic.Util in
  let module S = Ssr_api_shared.Components in
  {
    S.id = json |> member "id" |> to_int;
    S.post_id = json |> member "postId" |> to_int;
    S.name = json |> member "name" |> to_string;
    S.email = json |> member "email" |> to_string;
    S.body = json |> member "body" |> to_string;
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

let fetch_users () =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/users") in
  match result with
  | Ok json -> Lwt.return_ok (parse_users json)
  | Error e -> Lwt.return_error e

let fetch_user id =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/users/" ^ string_of_int id) in
  match result with
  | Ok json -> Lwt.return_ok (parse_user json)
  | Error e -> Lwt.return_error e

let fetch_posts () =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/posts?_limit=10") in
  match result with
  | Ok json -> Lwt.return_ok (parse_posts json)
  | Error e -> Lwt.return_error e

let fetch_user_posts user_id =
  let open Lwt.Syntax in
  let* result = fetch_json (api_base ^ "/users/" ^ string_of_int user_id ^ "/posts") in
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
let layout ~title:page_title ~current_path:_ ~children () =
  (* Ignore unused children warning for now *)
  let _ = (children : 'a list) in
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
          header h1 { margin: 0 0 8px 0; color: #2563eb; }
          header .subtitle { margin: 0 0 16px 0; color: #6b7280; }
          nav { display: flex; gap: 8px; flex-wrap: wrap; }
          .nav-link {
            padding: 8px 16px;
            text-decoration: none;
            color: #666;
            border-radius: 6px;
            transition: all 0.2s;
          }
          .nav-link:hover { background: #f0f0f0; color: #333; }
          .nav-link.active { background: #2563eb; color: white; }
          .nav-divider { color: #cbd5f5; }
          main {
            background: white;
            padding: 24px;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
          }
          .card {
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 12px;
            transition: all 0.2s;
          }
          .card:hover { 
            border-color: #2563eb;
            box-shadow: 0 2px 8px rgba(37,99,235,0.1);
          }
          .card h3 { margin: 0 0 8px 0; }
          .card h3 a { 
            color: #1f2937; 
            text-decoration: none;
          }
          .card h3 a:hover { color: #2563eb; }
          .card p { 
            color: #6b7280; 
            margin: 0;
            line-height: 1.5;
          }
          .card .meta { 
            font-size: 12px; 
            color: #9ca3af;
            margin-top: 8px;
          }
          .card .meta a { color: #2563eb; text-decoration: none; }
          .card .meta a:hover { text-decoration: underline; }
          .user-card { display: flex; gap: 16px; align-items: flex-start; }
          .user-card .avatar {
            width: 48px;
            height: 48px;
            background: #e5e7eb;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: #6b7280;
            flex-shrink: 0;
          }
          .user-card .info { flex: 1; }
          .user-card .info h3 { margin: 0 0 4px 0; }
          .user-card .info .username { color: #6b7280; margin: 0 0 8px 0; }
          .user-card .info .details { font-size: 13px; color: #9ca3af; }
          .detail-section { margin-top: 24px; }
          .detail-section h2 { margin-top: 0; color: #1f2937; }
          .detail-section .body { 
            line-height: 1.7; 
            color: #4b5563;
            white-space: pre-wrap;
          }
          .detail-section .meta {
            font-size: 14px;
            color: #9ca3af;
            margin-bottom: 16px;
          }
          .detail-section .meta a { color: #2563eb; text-decoration: none; }
          .detail-section .meta a:hover { text-decoration: underline; }
          .user-profile {
            display: flex;
            gap: 24px;
            align-items: flex-start;
            margin-bottom: 24px;
          }
          .user-profile .avatar {
            width: 80px;
            height: 80px;
            background: #e5e7eb;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 24px;
            color: #6b7280;
            flex-shrink: 0;
          }
          .user-profile .info h2 { margin: 0 0 4px 0; }
          .user-profile .info .username { color: #6b7280; margin: 0 0 12px 0; font-size: 16px; }
          .user-profile .info .details { display: grid; gap: 4px; font-size: 14px; color: #4b5563; }
          .user-profile .info .details a { color: #2563eb; text-decoration: none; }
          .user-profile .info .details a:hover { text-decoration: underline; }
          .comments-section { margin-top: 32px; }
          .comments-section h3 { 
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
          .breadcrumb {
            display: flex;
            gap: 8px;
            align-items: center;
            margin-bottom: 16px;
            font-size: 14px;
          }
          .breadcrumb a {
            color: #2563eb;
            text-decoration: none;
          }
          .breadcrumb a:hover { text-decoration: underline; }
          .breadcrumb .separator { color: #9ca3af; }
          .breadcrumb .current { color: #6b7280; }
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
          .section-title {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
          }
          .section-title h2 { margin: 0; }
          .section-title .count { color: #9ca3af; font-size: 14px; }
        </style>|};
      ] ();
      body ~children:[
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

let render_page ~current_path page =
  layout ~title:"API Explorer" ~current_path ~children:[
    C.app ~current_path ~page ()
  ] ()

(** Breadcrumb navigation *)
let breadcrumb items =
  let rec render = function
    | [] -> []
    | [(label, None)] -> 
      [Html.span ~class_:"current" ~children:[Html.text label] ()]
    | (label, Some href) :: rest ->
      Html.a ~href ~children:[Html.text label] () ::
      Html.span ~class_:"separator" ~children:[Html.text " / "] () ::
      render rest
    | (label, None) :: rest ->
      Html.span ~class_:"current" ~children:[Html.text label] () ::
      Html.span ~class_:"separator" ~children:[Html.text " / "] () ::
      render rest
  in
  Html.div ~class_:"breadcrumb" ~children:(render items) ()

(** Render a post card for the list view *)
let post_card ?(show_user=true) (post : post) =
  Html.(
    div ~class_:"card" ~children:[
      h3 ~children:[
        a ~href:("/posts/" ^ string_of_int post.id) ~children:[
          text post.title
        ] ()
      ] ();
      p ~children:[
        text (String.sub post.body 0 (min 120 (String.length post.body)) ^ "...")
      ] ();
      div ~class_:"meta" ~children:(
        if show_user then [
          text "Post #";
          text (string_of_int post.id);
          text " by ";
          a ~href:("/users/" ^ string_of_int post.user_id) ~children:[
            text ("User #" ^ string_of_int post.user_id)
          ] ()
        ] else [
          text ("Post #" ^ string_of_int post.id)
        ]
      ) ();
    ] ()
  )

(** Render a user card for the list view *)
let user_card (user : user) =
  let initial = String.sub user.name 0 1 in
  Html.(
    div ~class_:"card user-card" ~children:[
      div ~class_:"avatar" ~children:[text initial] ();
      div ~class_:"info" ~children:[
        h3 ~children:[
          a ~href:("/users/" ^ string_of_int user.id) ~children:[
            text user.name
          ] ()
        ] ();
        p ~class_:"username" ~children:[text ("@" ^ user.username)] ();
        div ~class_:"details" ~children:[
          text (user.email ^ " · " ^ user.city)
        ] ();
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

(** {1 Page Components} *)

let posts_page ~posts () =
  layout ~title:"Posts - API Explorer" ~current_path:"/" ~children:(
    Html.[
      div ~class_:"section-title" ~children:[
        h2 ~children:[text "Recent Posts"] ();
        span ~class_:"count" ~children:[
          text (string_of_int (List.length posts) ^ " posts")
        ] ();
      ] ();
      p ~children:[
        text "Click on a post to view details and comments, or click on a user to see their profile."
      ] ();
      div ~id:"posts-list" ~children:(List.map (post_card ~show_user:true) posts) ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Links now use client-side navigation."
      ] ();
    ]
  ) ()

let users_page ~users () =
  layout ~title:"Users - API Explorer" ~current_path:"/users" ~children:(
    Html.[
      div ~class_:"section-title" ~children:[
        h2 ~children:[text "All Users"] ();
        span ~class_:"count" ~children:[
          text (string_of_int (List.length users) ^ " users")
        ] ();
      ] ();
      p ~children:[
        text "Click on a user to view their profile and posts."
      ] ();
      div ~id:"users-list" ~children:(List.map user_card users) ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Links now use client-side navigation."
      ] ();
    ]
  ) ()

let user_page ~(user : user) ~posts () =
  let initial = String.sub user.name 0 1 in
  layout ~title:(user.name ^ " - API Explorer") 
    ~current_path:("/users/" ^ string_of_int user.id) ~children:(
    Html.[
      breadcrumb [("Users", Some "/users"); (user.name, None)];
      div ~class_:"user-profile" ~children:[
        div ~class_:"avatar" ~children:[text initial] ();
        div ~class_:"info" ~children:[
          h2 ~children:[text user.name] ();
          p ~class_:"username" ~children:[text ("@" ^ user.username)] ();
          div ~class_:"details" ~children:[
            span ~children:[text ("Email: " ^ user.email)] ();
            span ~children:[text ("Phone: " ^ user.phone)] ();
            span ~children:[
              text "Website: ";
              a ~href:("https://" ^ user.website) ~target:"_blank" ~children:[
                text user.website
              ] ()
            ] ();
            span ~children:[text ("Location: " ^ user.city)] ();
            span ~children:[text ("Company: " ^ user.company)] ();
          ] ();
        ] ();
      ] ();
      div ~class_:"detail-section" ~id:"user-posts" ~children:[
        div ~class_:"section-title" ~children:[
          h3 ~children:[text "Posts"] ();
          span ~class_:"count" ~children:[
            text (string_of_int (List.length posts) ^ " posts")
          ] ();
        ] ();
        div ~id:"posts-list" ~children:(List.map (post_card ~show_user:false) posts) ();
      ] ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Navigation is now client-side."
      ] ();
    ]
  ) ()

let post_page ~(post : post) ~comments ~(author : user) () =
  layout ~title:(post.title ^ " - API Explorer") 
    ~current_path:("/posts/" ^ string_of_int post.id) ~children:(
    Html.[
      breadcrumb [
        ("Posts", Some "/"); 
        (post.title, None)
      ];
      div ~class_:"detail-section" ~id:"post-detail" ~children:[
        h2 ~children:[text post.title] ();
        div ~class_:"meta" ~children:[
          text "By ";
          a ~href:("/users/" ^ string_of_int author.id) ~children:[
            text author.name
          ] ();
          text (" (@" ^ author.username ^ ")");
        ] ();
        div ~class_:"body" ~children:[text post.body] ();
      ] ();
      div ~class_:"comments-section" ~id:"comments-section" ~children:[
        div ~class_:"section-title" ~children:[
          h3 ~children:[text "Comments"] ();
          span ~class_:"count" ~children:[
            text (string_of_int (List.length comments) ^ " comments")
          ] ();
        ] ();
        div ~id:"comments-list" ~children:(List.map comment_view comments) ();
      ] ();
      div ~id:"hydration-status" ~class_:"hydration-status" ~children:[
        text "Hydrated! Navigation is now client-side."
      ] ();
    ]
  ) ()

let error_page ~message () =
  layout ~title:"Error - API Explorer" ~current_path:"" ~children:(
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

let not_found_page ~request_path () =
  layout ~title:"Not Found - API Explorer" ~current_path:request_path ~children:(
    Html.[
      h2 ~children:[text "404 - Page Not Found"] ();
      p ~children:[
        text "The page ";
        code ~children:[text request_path] ();
        text " was not found.";
      ] ();
      p ~children:[
        a ~href:"/" ~children:[text "Go back home"] ()
      ] ();
    ]
  ) ()

(** {1 API Endpoints for Client-Side Fetching} *)

let handle_api_users _req =
  let open Lwt.Syntax in
  let* result = fetch_users () in
  match result with
  | Ok users ->
    let json = `List (List.map (fun (u : user) ->
      `Assoc [
        ("id", `Int u.id);
        ("name", `String u.name);
        ("username", `String u.username);
        ("email", `String u.email);
        ("phone", `String u.phone);
        ("website", `String u.website);
        ("company", `String u.company);
        ("city", `String u.city);
      ]
    ) users) in
    Dream.json (Yojson.Basic.to_string json)
  | Error e ->
    Dream.json ~status:`Internal_Server_Error 
      (Printf.sprintf {|{"error": "%s"}|} e)

let handle_api_user req =
  let open Lwt.Syntax in
  let id = Dream.param req "id" |> int_of_string in
  let* result = fetch_user id in
  match result with
  | Ok user ->
    let json = `Assoc [
      ("id", `Int user.id);
      ("name", `String user.name);
      ("username", `String user.username);
      ("email", `String user.email);
      ("phone", `String user.phone);
      ("website", `String user.website);
      ("company", `String user.company);
      ("city", `String user.city);
    ] in
    Dream.json (Yojson.Basic.to_string json)
  | Error e ->
    Dream.json ~status:`Internal_Server_Error 
      (Printf.sprintf {|{"error": "%s"}|} e)

let handle_api_user_posts req =
  let open Lwt.Syntax in
  let user_id = Dream.param req "id" |> int_of_string in
  let* result = fetch_user_posts user_id in
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
    let json = `List (List.map (fun (c : comment) ->
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
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Posts) (Shared.Posts_page (Shared.Ready posts)))
    in
    Dream.html html
  | Error e ->
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Posts) (Shared.Posts_page (Shared.Error e)))
    in
    Dream.html ~status:`Internal_Server_Error html

let handle_users _req =
  let open Lwt.Syntax in
  let* result = fetch_users () in
  match result with
  | Ok users ->
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Users) (Shared.Users_page (Shared.Ready users)))
    in
    Dream.html html
  | Error e ->
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Users) (Shared.Users_page (Shared.Error e)))
    in
    Dream.html ~status:`Internal_Server_Error html

let handle_user req =
  let open Lwt.Syntax in
  let id = 
    try Some (Dream.param req "id" |> int_of_string)
    with _ -> None
  in
  match id with
  | None ->
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Users) (Shared.Not_found "Invalid user ID"))
    in
    Dream.html ~status:`Bad_Request html
  | Some id ->
    let* user_result = fetch_user id in
    let* posts_result = fetch_user_posts id in
    match user_result, posts_result with
    | Ok user, Ok posts ->
      let html = Render.to_document (fun () ->
        render_page ~current_path:(Routes.path (Routes.User user.id))
          (Shared.User_page (Shared.Ready user, Shared.Ready posts)))
      in
      Dream.html html
    | Error e, _ | _, Error e ->
      let html = Render.to_document (fun () ->
        render_page ~current_path:(Routes.path (Routes.User id))
          (Shared.User_page (Shared.Error e, Shared.Error e)))
      in
      Dream.html ~status:`Internal_Server_Error html

let handle_post req =
  let open Lwt.Syntax in
  let id = 
    try Some (Dream.param req "id" |> int_of_string)
    with _ -> None
  in
  match id with
  | None ->
    let html = Render.to_document (fun () ->
    render_page ~current_path:(Routes.path Routes.Posts) (Shared.Not_found "Invalid post ID"))
    in
    Dream.html ~status:`Bad_Request html
  | Some id ->
    let* post_result = fetch_post id in
    match post_result with
    | Error e ->
      let html = Render.to_document (fun () ->
        render_page ~current_path:(Routes.path (Routes.Post id))
          (Shared.Post_page (Shared.Error e, Shared.Error e)))
      in
      Dream.html ~status:`Internal_Server_Error html
    | Ok post ->
      let* comments_result = fetch_comments id in
      match comments_result with
      | Ok comments ->
        let html = Render.to_document (fun () ->
          render_page ~current_path:(Routes.path (Routes.Post post.id))
            (Shared.Post_page (Shared.Ready post, Shared.Ready comments)))
        in
        Dream.html html
      | Error e ->
        let html = Render.to_document (fun () ->
          render_page ~current_path:(Routes.path (Routes.Post post.id))
            (Shared.Post_page (Shared.Error e, Shared.Error e)))
        in
        Dream.html ~status:`Internal_Server_Error html

let handle_not_found req =
  let path = Dream.target req in
  let html = Render.to_document (fun () ->
    render_page ~current_path:path (Shared.Not_found ("Page not found: " ^ path)))
  in
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
  Printf.printf "  http://localhost:%d/users      - All users\n" port;
  Printf.printf "  http://localhost:%d/users/:id  - User profile\n" port;
  Printf.printf "\n";
  Printf.printf "Press Ctrl+C to stop\n";
  flush stdout;
  
  Dream.run ~port
  @@ Dream.router [
    (* Health check *)
    Dream.get "/ping" (fun _req -> Dream.respond ~status:`OK "pong");
    (* API endpoints for client-side fetching *)
    Dream.get "/api/users" handle_api_users;
    Dream.get "/api/users/:id" handle_api_user;
    Dream.get "/api/users/:id/posts" handle_api_user_posts;
    Dream.get "/api/posts" handle_api_posts;
    Dream.get "/api/posts/:id" handle_api_post;
    Dream.get "/api/posts/:id/comments" handle_api_comments;
    (* HTML pages *)
    Dream.get "/" handle_posts;
    Dream.get "/posts/:id" handle_post;
    Dream.get "/users" handle_users;
    Dream.get "/users/:id" handle_user;
    (* Static files *)
    Dream.get "/static/**" (Dream.static "examples/ssr_api_app/static");
    (* 404 fallback *)
    Dream.any "/**" handle_not_found;
  ]

(* Suppress unused warnings for example page components *)
(* These are provided as examples for potential future use *)
let _ = (posts_page, users_page, user_page, post_page, error_page, not_found_page)

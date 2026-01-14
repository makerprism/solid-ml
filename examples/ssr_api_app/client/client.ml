(** SSR API App Example - Client Hydration
    
    This script hydrates the server-rendered HTML and enables:
    - Client-side navigation without full page reloads
    - Loading states during data fetching
    - Dynamic content updates
    
    Build with: make example-ssr-api-client
*)

open Solid_ml_browser

(** {1 DOM Helpers} *)

let get_element id = Dom.get_element_by_id (Dom.document ()) id
let query_selector sel = Dom.query_selector (Dom.document ()) sel
let query_selector_all sel = Dom.query_selector_all (Dom.document ()) sel

(** {1 Fetch API via Raw JS} *)

(* Use raw JS for fetch since it's simpler than complex FFI bindings *)
let fetch_json_raw : string -> (string -> unit) -> (string -> unit) -> unit = 
  [%mel.raw {|
    function(url, onSuccess, onError) {
      fetch(url)
        .then(function(resp) { return resp.json(); })
        .then(function(data) { onSuccess(JSON.stringify(data)); })
        .catch(function(err) { onError(err.message || "Fetch failed"); });
    }
  |}]

(** {1 JSON Parsing Helpers} *)

(* Simple helpers to extract data from JSON strings *)
let json_get_string : string -> string -> string = [%mel.raw {|
  function(json, key) {
    try {
      var obj = JSON.parse(json);
      return obj[key] || "";
    } catch(e) { return ""; }
  }
|}]

let json_get_int : string -> string -> int = [%mel.raw {|
  function(json, key) {
    try {
      var obj = JSON.parse(json);
      return obj[key] || 0;
    } catch(e) { return 0; }
  }
|}]

(* Returns a JS array of strings, we'll convert to list in OCaml *)
let json_array_map_raw : string -> (string -> string) -> string array = [%mel.raw {|
  function(json, fn) {
    try {
      var arr = JSON.parse(json);
      return arr.map(function(item) { return fn(JSON.stringify(item)); });
    } catch(e) { return []; }
  }
|}]

let json_array_map json fn =
  Array.to_list (json_array_map_raw json fn)

(** {1 Data Types and Parsing} *)

type user = {
  id : int;
  name : string;
  username : string;
  email : string;
  phone : string;
  website : string;
  company : string;
  city : string;
}

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

let parse_user json : user = {
  id = json_get_int json "id";
  name = json_get_string json "name";
  username = json_get_string json "username";
  email = json_get_string json "email";
  phone = json_get_string json "phone";
  website = json_get_string json "website";
  company = json_get_string json "company";
  city = json_get_string json "city";
}

let parse_post json : post = {
  id = json_get_int json "id";
  user_id = json_get_int json "userId";
  title = json_get_string json "title";
  body = json_get_string json "body";
}

let parse_comment json : comment = {
  id = json_get_int json "id";
  post_id = json_get_int json "postId";
  name = json_get_string json "name";
  email = json_get_string json "email";
  body = json_get_string json "body";
}

(** {1 API Fetching} *)

let fetch_users on_success on_error =
  fetch_json_raw "/api/users"
    (fun json ->
      let users = json_array_map json (fun item -> item) |> List.map parse_user in
      on_success users)
    on_error

let fetch_user id on_success on_error =
  fetch_json_raw ("/api/users/" ^ string_of_int id)
    (fun json -> on_success (parse_user json))
    on_error

let fetch_user_posts user_id on_success on_error =
  fetch_json_raw ("/api/users/" ^ string_of_int user_id ^ "/posts")
    (fun json ->
      let posts = json_array_map json (fun item -> item) |> List.map parse_post in
      on_success posts)
    on_error

let fetch_posts on_success on_error =
  fetch_json_raw "/api/posts" 
    (fun json -> 
      let posts = json_array_map json (fun item -> item) |> List.map parse_post in
      on_success posts)
    on_error

let fetch_post id on_success on_error =
  fetch_json_raw ("/api/posts/" ^ string_of_int id)
    (fun json -> on_success (parse_post json))
    on_error

let fetch_comments post_id on_success on_error =
  fetch_json_raw ("/api/posts/" ^ string_of_int post_id ^ "/comments")
    (fun json ->
      let comments = json_array_map json (fun item -> item) |> List.map parse_comment in
      on_success comments)
    on_error

(** {1 HTML Rendering} *)

let html_escape s =
  let b = Buffer.create (String.length s) in
  String.iter (function
    | '<' -> Buffer.add_string b "&lt;"
    | '>' -> Buffer.add_string b "&gt;"
    | '&' -> Buffer.add_string b "&amp;"
    | '"' -> Buffer.add_string b "&quot;"
    | c -> Buffer.add_char b c
  ) s;
  Buffer.contents b

let render_post_card ?(show_user=true) (post : post) =
  let meta = 
    if show_user then
      {|Post #|} ^ string_of_int post.id ^ {| by <a href="/users/|} ^ string_of_int post.user_id ^ {|">User #|} ^ string_of_int post.user_id ^ {|</a>|}
    else
      {|Post #|} ^ string_of_int post.id
  in
  {|<div class="card">
    <h3><a href="/posts/|} ^ string_of_int post.id ^ {|">|} ^ html_escape post.title ^ {|</a></h3>
    <p>|} ^ html_escape (String.sub post.body 0 (min 120 (String.length post.body))) ^ {|...</p>
    <div class="meta">|} ^ meta ^ {|</div>
  </div>|}

let render_posts_list ?(show_user=true) posts =
  String.concat "\n" (List.map (render_post_card ~show_user) posts)

let render_user_card (user : user) =
  let initial = if String.length user.name > 0 then String.sub user.name 0 1 else "?" in
  {|<div class="card user-card">
    <div class="avatar">|} ^ initial ^ {|</div>
    <div class="info">
      <h3><a href="/users/|} ^ string_of_int user.id ^ {|">|} ^ html_escape user.name ^ {|</a></h3>
      <p class="username">@|} ^ html_escape user.username ^ {|</p>
      <div class="details">|} ^ html_escape user.email ^ {| · |} ^ html_escape user.city ^ {|</div>
    </div>
  </div>|}

let render_users_list users =
  String.concat "\n" (List.map render_user_card users)

let render_comment (comment : comment) =
  {|<div class="comment">
    <div class="author">|} ^ html_escape comment.name ^ {|</div>
    <div class="email">|} ^ html_escape comment.email ^ {|</div>
    <div class="body">|} ^ html_escape comment.body ^ {|</div>
  </div>|}

let render_comments comments =
  String.concat "\n" (List.map render_comment comments)

let render_loading () = {|<div class="loading">Loading...</div>|}

let render_error msg = 
  {|<div class="error"><h2>Error</h2><p>|} ^ html_escape msg ^ {|</p></div>|}

let render_breadcrumb items =
  let rec render = function
    | [] -> ""
    | [(label, None)] -> 
      {|<span class="current">|} ^ html_escape label ^ {|</span>|}
    | (label, Some href) :: rest ->
      {|<a href="|} ^ href ^ {|">|} ^ html_escape label ^ {|</a><span class="separator"> / </span>|} ^ render rest
    | (label, None) :: rest ->
      {|<span class="current">|} ^ html_escape label ^ {|</span><span class="separator"> / </span>|} ^ render rest
  in
  {|<div class="breadcrumb">|} ^ render items ^ {|</div>|}

let render_hydration_status () =
  {|<div id="hydration-status" class="hydration-status active">Client-side navigation active.</div>|}

(** {1 Client-Side Routing} *)

let current_path = ref (Dom.get_pathname ())

(** Set up click handlers for all internal links *)
let rec setup_links () =
  (* Select all internal links *)
  let links = query_selector_all "a[href^='/']" in
  List.iter (fun link ->
    (* Skip external links and already-setup links *)
    match Dom.get_attribute link "data-setup" with
    | Some _ -> ()
    | None ->
      Dom.set_attribute link "data-setup" "true";
      Dom.add_event_listener link "click" (fun evt ->
        match Dom.get_attribute link "href" with
        | Some href when String.length href > 0 && href.[0] = '/' ->
          Dom.prevent_default evt;
          navigate href
        | _ -> ()
      )
  ) links

(** Navigate to a new path and render content *)
and navigate path =
  Dom.log ("Navigating to: " ^ path);
  current_path := path;
  Dom.push_state path;
  render_page path

(** Render page based on path *)
and render_page path =
  Dom.log ("Rendering page: " ^ path);
  match get_element "app" with
  | None -> 
    Dom.log "Error: #app element not found";
    ()
  | Some app_el ->
    (* Route matching *)
    if path = "/" then
      render_posts_page app_el
    else if path = "/users" then
      render_users_page app_el
    else if String.length path > 7 && String.sub path 0 7 = "/posts/" then begin
      let id_str = String.sub path 7 (String.length path - 7) in
      match int_of_string_opt id_str with
      | Some id -> render_post_page app_el id
      | None -> Dom.set_inner_html app_el (render_error "Invalid post ID")
    end
    else if String.length path > 7 && String.sub path 0 7 = "/users/" then begin
      let id_str = String.sub path 7 (String.length path - 7) in
      match int_of_string_opt id_str with
      | Some id -> render_user_page app_el id
      | None -> Dom.set_inner_html app_el (render_error "Invalid user ID")
    end
    else
      Dom.set_inner_html app_el (render_error ("Page not found: " ^ path))

(** Render posts list page *)
and render_posts_page app_el =
  Dom.log "Rendering posts page...";
  Dom.set_inner_html app_el (
    {|<div class="section-title">
      <h2>Recent Posts</h2>
      <span class="count">Loading...</span>
    </div>
    <p>Click on a post to view details and comments, or click on a user to see their profile.</p>
    <div id="content-list">|} ^ render_loading () ^ {|</div>
    |} ^ render_hydration_status ()
  );
  setup_links ();
  (* Fetch and render posts *)
  fetch_posts 
    (fun posts ->
      Dom.log ("Fetched " ^ string_of_int (List.length posts) ^ " posts");
      match get_element "content-list" with
      | Some el -> 
        Dom.log "Found content-list, updating...";
        Dom.set_inner_html el (render_posts_list ~show_user:true posts);
        (* Update count *)
        (match query_selector ".section-title .count" with
         | Some count_el -> Dom.set_inner_html count_el (string_of_int (List.length posts) ^ " posts")
         | None -> ());
        setup_links ()
      | None -> 
        Dom.log "Error: content-list not found")
    (fun err ->
      Dom.log ("Error fetching posts: " ^ err);
      match get_element "content-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load posts: " ^ err))
      | None -> ())

(** Render users list page *)
and render_users_page app_el =
  Dom.log "Rendering users page...";
  Dom.set_inner_html app_el (
    {|<div class="section-title">
      <h2>All Users</h2>
      <span class="count">Loading...</span>
    </div>
    <p>Click on a user to view their profile and posts.</p>
    <div id="content-list">|} ^ render_loading () ^ {|</div>
    |} ^ render_hydration_status ()
  );
  setup_links ();
  (* Fetch and render users *)
  fetch_users
    (fun users ->
      Dom.log ("Fetched " ^ string_of_int (List.length users) ^ " users");
      match get_element "content-list" with
      | Some el ->
        Dom.set_inner_html el (render_users_list users);
        (* Update count *)
        (match query_selector ".section-title .count" with
         | Some count_el -> Dom.set_inner_html count_el (string_of_int (List.length users) ^ " users")
         | None -> ());
        setup_links ()
      | None -> 
        Dom.log "Error: content-list not found")
    (fun err ->
      Dom.log ("Error fetching users: " ^ err);
      match get_element "content-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load users: " ^ err))
      | None -> ())

(** Render user detail page *)
and render_user_page app_el user_id =
  Dom.log ("Rendering user page for ID: " ^ string_of_int user_id);
  Dom.set_inner_html app_el (
    render_breadcrumb [("Users", Some "/users"); ("Loading...", None)] ^
    {|<div id="user-profile">|} ^ render_loading () ^ {|</div>
    <div class="detail-section" id="user-posts">
      <div class="section-title">
        <h3>Posts</h3>
        <span class="count">Loading...</span>
      </div>
      <div id="content-list">|} ^ render_loading () ^ {|</div>
    </div>
    |} ^ render_hydration_status ()
  );
  setup_links ();
  (* Fetch user *)
  fetch_user user_id
    (fun user ->
      Dom.log ("Fetched user: " ^ user.name);
      let initial = if String.length user.name > 0 then String.sub user.name 0 1 else "?" in
      (* Update breadcrumb *)
      (match query_selector ".breadcrumb" with
       | Some bc -> Dom.set_inner_html bc (
           {|<a href="/users">Users</a><span class="separator"> / </span><span class="current">|} ^ html_escape user.name ^ {|</span>|}
         )
       | None -> ());
      (* Update profile *)
      match get_element "user-profile" with
      | Some el ->
        Dom.set_inner_html el (
          {|<div class="user-profile">
            <div class="avatar">|} ^ initial ^ {|</div>
            <div class="info">
              <h2>|} ^ html_escape user.name ^ {|</h2>
              <p class="username">@|} ^ html_escape user.username ^ {|</p>
              <div class="details">
                <span>Email: |} ^ html_escape user.email ^ {|</span>
                <span>Phone: |} ^ html_escape user.phone ^ {|</span>
                <span>Website: <a href="https://|} ^ html_escape user.website ^ {|" target="_blank">|} ^ html_escape user.website ^ {|</a></span>
                <span>Location: |} ^ html_escape user.city ^ {|</span>
                <span>Company: |} ^ html_escape user.company ^ {|</span>
              </div>
            </div>
          </div>|}
        );
        setup_links ()
      | None -> ())
    (fun err ->
      Dom.log ("Error fetching user: " ^ err);
      match get_element "user-profile" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load user: " ^ err))
      | None -> ());
  (* Fetch user's posts *)
  fetch_user_posts user_id
    (fun posts ->
      Dom.log ("Fetched " ^ string_of_int (List.length posts) ^ " posts for user");
      match get_element "content-list" with
      | Some el ->
        Dom.set_inner_html el (render_posts_list ~show_user:false posts);
        (* Update count *)
        (match query_selector "#user-posts .count" with
         | Some count_el -> Dom.set_inner_html count_el (string_of_int (List.length posts) ^ " posts")
         | None -> ());
        setup_links ()
      | None ->
        Dom.log "Error: content-list not found")
    (fun err ->
      Dom.log ("Error fetching user posts: " ^ err);
      match get_element "content-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load posts: " ^ err))
      | None -> ())

(** Render single post page *)
and render_post_page app_el post_id =
  Dom.log ("Rendering post page for ID: " ^ string_of_int post_id);
  Dom.set_inner_html app_el (
    render_breadcrumb [("Posts", Some "/"); ("Loading...", None)] ^
    {|<div class="detail-section" id="post-detail">|} ^ render_loading () ^ {|</div>
    <div class="comments-section" id="comments-section">
      <div class="section-title">
        <h3>Comments</h3>
        <span class="count">Loading...</span>
      </div>
      <div id="comments-list">|} ^ render_loading () ^ {|</div>
    </div>
    |} ^ render_hydration_status ()
  );
  setup_links ();
  (* Fetch post *)
  fetch_post post_id
    (fun post ->
      Dom.log ("Fetched post: " ^ post.title);
      (* Update breadcrumb *)
      (match query_selector ".breadcrumb" with
       | Some bc -> Dom.set_inner_html bc (
           {|<a href="/">Posts</a><span class="separator"> / </span><span class="current">|} ^ html_escape post.title ^ {|</span>|}
         )
       | None -> ());
      (* Fetch author info *)
      fetch_user post.user_id
        (fun author ->
          match get_element "post-detail" with
          | Some el ->
            Dom.set_inner_html el (
              {|<h2>|} ^ html_escape post.title ^ {|</h2>
              <div class="meta">By <a href="/users/|} ^ string_of_int author.id ^ {|">|} ^ html_escape author.name ^ {|</a> (@|} ^ html_escape author.username ^ {|)</div>
              <div class="body">|} ^ html_escape post.body ^ {|</div>|}
            );
            setup_links ()
          | None -> ())
        (fun _ ->
          (* Show post without author details if author fetch fails *)
          match get_element "post-detail" with
          | Some el ->
            Dom.set_inner_html el (
              {|<h2>|} ^ html_escape post.title ^ {|</h2>
              <div class="meta">By <a href="/users/|} ^ string_of_int post.user_id ^ {|">User #|} ^ string_of_int post.user_id ^ {|</a></div>
              <div class="body">|} ^ html_escape post.body ^ {|</div>|}
            );
            setup_links ()
          | None -> ()))
    (fun err ->
      Dom.log ("Error fetching post: " ^ err);
      match get_element "post-detail" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load post: " ^ err))
      | None -> ());
  (* Fetch comments *)
  fetch_comments post_id
    (fun comments ->
      Dom.log ("Fetched " ^ string_of_int (List.length comments) ^ " comments");
      match get_element "comments-list" with
      | Some el -> 
        Dom.set_inner_html el (render_comments comments);
        (* Update count *)
        (match query_selector "#comments-section .count" with
         | Some count_el -> Dom.set_inner_html count_el (string_of_int (List.length comments) ^ " comments")
         | None -> ())
      | None ->
        Dom.log "Error: comments-list not found")
    (fun err ->
      Dom.log ("Error fetching comments: " ^ err);
      match get_element "comments-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load comments: " ^ err))
      | None -> ())

(** {1 Initial Setup} *)

let setup_navigation () =
  (* Handle browser back/forward *)
  Dom.on_popstate (fun _evt ->
    let path = Dom.get_pathname () in
    Dom.log ("Popstate event, path: " ^ path);
    current_path := path;
    render_page path
  );
  (* Set up initial links *)
  setup_links ()

(** {1 Main Entry Point} *)

let () =
  let (_result, _dispose) = Reactive_core.create_root (fun () ->
    let path = Dom.get_pathname () in
    Dom.log ("Hydrating page: " ^ path);
    
    (* Set up navigation *)
    setup_navigation ();
    
    (* Show hydration status *)
    (match get_element "hydration-status" with
    | Some el -> Dom.add_class el "active"
    | None -> ());
    
    Dom.log "Hydration complete!"
  ) in
  ()

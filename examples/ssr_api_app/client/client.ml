(** SSR API App Example - Client Hydration
    
    This script hydrates the server-rendered HTML and enables:
    - Client-side navigation without full page reloads
    - Loading states during data fetching
    - Dynamic content updates
    
    Build with: make example-ssr-api-client
*)

open Solid_ml_browser

(** {1 DOM Helpers} *)

let get_element id = Dom.get_element_by_id Dom.document id
let query_selector sel = Dom.query_selector Dom.document sel
let query_selector_all sel = Dom.query_selector_all Dom.document sel

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

let json_array_map : string -> (string -> string) -> string list = [%mel.raw {|
  function(json, fn) {
    try {
      var arr = JSON.parse(json);
      return arr.map(function(item) { return fn(JSON.stringify(item)); });
    } catch(e) { return []; }
  }
|}]

(** {1 Data Types and Parsing} *)

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

let render_post_card (post : post) =
  {|<div class="post-card">
    <h3><a href="/posts/|} ^ string_of_int post.id ^ {|" data-link>|} ^ html_escape post.title ^ {|</a></h3>
    <p>|} ^ html_escape (String.sub post.body 0 (min 120 (String.length post.body))) ^ {|...</p>
    <div class="meta">Post #|} ^ string_of_int post.id ^ {| by User #|} ^ string_of_int post.user_id ^ {|</div>
  </div>|}

let render_posts_list posts =
  String.concat "\n" (List.map render_post_card posts)

let render_comment (comment : comment) =
  {|<div class="comment">
    <div class="author">|} ^ html_escape comment.name ^ {|</div>
    <div class="email">|} ^ html_escape comment.email ^ {|</div>
    <div class="body">|} ^ html_escape comment.body ^ {|</div>
  </div>|}

let render_comments comments =
  String.concat "\n" (List.map render_comment comments)

let render_post_detail (post : post) =
  {|<h2>|} ^ html_escape post.title ^ {|</h2>
  <div class="meta">Post #|} ^ string_of_int post.id ^ {| by User #|} ^ string_of_int post.user_id ^ {|</div>
  <div class="body">|} ^ html_escape post.body ^ {|</div>|}

let render_loading () = {|<div class="loading">Loading...</div>|}

let render_error msg = 
  {|<div class="error"><h2>Error</h2><p>|} ^ html_escape msg ^ {|</p></div>|}

(** {1 Client-Side Routing} *)

let current_path = ref (Dom.get_pathname ())

(** Set up click handlers for links *)
let rec setup_links () =
  let links = query_selector_all "a[data-link], .post-card h3 a, .back-link, .nav-link" in
  List.iter (fun link ->
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
  if path <> !current_path then begin
    current_path := path;
    Dom.push_state path;
    render_page path
  end

(** Render page based on path *)
and render_page path =
  match get_element "app" with
  | None -> ()
  | Some app_el ->
    (* Check if this is a post detail page *)
    if String.length path > 7 && String.sub path 0 7 = "/posts/" then begin
      let id_str = String.sub path 7 (String.length path - 7) in
      match int_of_string_opt id_str with
      | Some id -> render_post_page app_el id
      | None -> Dom.set_inner_html app_el (render_error "Invalid post ID")
    end
    else if path = "/" then
      render_posts_page app_el
    else
      Dom.set_inner_html app_el (render_error ("Page not found: " ^ path))

(** Render posts list page *)
and render_posts_page app_el =
  Dom.set_inner_html app_el (
    {|<h2>Recent Posts</h2>
    <p>Click on a post to view details and comments.</p>
    <div id="posts-list">|} ^ render_loading () ^ {|</div>
    <div id="hydration-status" class="hydration-status active">
      Client-side navigation active.
    </div>|}
  );
  (* Fetch and render posts *)
  fetch_posts 
    (fun posts ->
      match get_element "posts-list" with
      | Some el -> 
        Dom.set_inner_html el (render_posts_list posts);
        setup_links ()
      | None -> ())
    (fun err ->
      match get_element "posts-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load posts: " ^ err))
      | None -> ())

(** Render single post page *)
and render_post_page app_el post_id =
  Dom.set_inner_html app_el (
    {|<a href="/" class="back-link" data-link>← Back to all posts</a>
    <div class="post-detail" id="post-detail">|} ^ render_loading () ^ {|</div>
    <div class="comments" id="comments-section">
      <h3>Comments</h3>
      <div id="comments-list">|} ^ render_loading () ^ {|</div>
    </div>
    <div id="hydration-status" class="hydration-status active">
      Client-side navigation active.
    </div>|}
  );
  setup_links ();
  (* Fetch post *)
  fetch_post post_id
    (fun post ->
      match get_element "post-detail" with
      | Some el -> Dom.set_inner_html el (render_post_detail post)
      | None -> ())
    (fun err ->
      match get_element "post-detail" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load post: " ^ err))
      | None -> ());
  (* Fetch comments *)
  fetch_comments post_id
    (fun comments ->
      match get_element "comments-section" with
      | Some el -> 
        Dom.set_inner_html el (
          {|<h3>Comments (|} ^ string_of_int (List.length comments) ^ {|)</h3>
          <div id="comments-list">|} ^ render_comments comments ^ {|</div>|}
        )
      | None -> ())
    (fun err ->
      match get_element "comments-list" with
      | Some el -> Dom.set_inner_html el (render_error ("Failed to load comments: " ^ err))
      | None -> ())

(** {1 Initial Setup} *)

let setup_navigation () =
  (* Handle browser back/forward *)
  Dom.on_popstate (fun _evt ->
    let path = Dom.get_pathname () in
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

(** SSR API App Example - Client Hydration

    This script hydrates the server-rendered HTML and enables:
    - Client-side navigation without full page reloads
    - Loading states during data fetching
    - Dynamic content updates

    Build with: make example-ssr-api-client
*)

open Solid_ml_browser

module Shared = Ssr_api_shared.Components
module C = Shared.App (Solid_ml_browser.Env)

type user = Shared.user
type post = Shared.post
type comment = Shared.comment

(** {1 DOM Helpers} *)

let get_element id = Dom.get_element_by_id (Dom.document ()) id
let query_selector_all sel = Dom.query_selector_all (Dom.document ()) sel

(** {1 Fetch API via Raw JS} *)

let fetch_json_raw : string -> (string -> unit) -> (string -> unit) -> unit =
  [%mel.raw {|
    function(url, onSuccess, onError) {
      fetch(url)
        .then(function(resp) { return resp.json(); })
        .then(function(data) { onSuccess(JSON.stringify(data)); })
        .catch(function(err) { onError(err.message || "Fetch failed"); });
    }
  |}]

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

let json_array_map_raw : string -> (string -> 'a) -> 'a array = [%mel.raw {|
  function(json, fn) {
    try {
      var arr = JSON.parse(json);
      return arr.map(function(item) { return fn(JSON.stringify(item)); });
    } catch(e) { return []; }
  }
|}]

let json_array_map json fn =
  Array.to_list (json_array_map_raw json fn)

(** {1 Data Parsing} *)

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

let parse_users json = json_array_map json parse_user
let parse_posts json = json_array_map json parse_post
let parse_comments json = json_array_map json parse_comment

(** {1 API Fetching} *)

let api_base = "https://jsonplaceholder.typicode.com"

let fetch_users on_ok on_err =
  fetch_json_raw (api_base ^ "/users")
    (fun json -> on_ok (parse_users json))
    on_err

let fetch_posts on_ok on_err =
  fetch_json_raw (api_base ^ "/posts?_limit=10")
    (fun json -> on_ok (parse_posts json))
    on_err

let fetch_user id on_ok on_err =
  fetch_json_raw (api_base ^ "/users/" ^ string_of_int id)
    (fun json -> on_ok (parse_user json))
    on_err

let fetch_user_posts id on_ok on_err =
  fetch_json_raw (api_base ^ "/users/" ^ string_of_int id ^ "/posts")
    (fun json -> on_ok (parse_posts json))
    on_err

let fetch_post id on_ok on_err =
  fetch_json_raw (api_base ^ "/posts/" ^ string_of_int id)
    (fun json -> on_ok (parse_post json))
    on_err

let fetch_comments id on_ok on_err =
  fetch_json_raw (api_base ^ "/posts/" ^ string_of_int id ^ "/comments")
    (fun json -> on_ok (parse_comments json))
    on_err

(** {1 Rendering} *)

let current_path = ref "/"

let render_app app_el page =
  let _dispose = Render.render app_el (fun () ->
    C.app ~current_path:!current_path ~page ()
  ) in
  ()

let render_posts_page app_el =
  Dom.log "Rendering posts page...";
  render_app app_el (Shared.Posts_page Shared.Loading);
  fetch_posts
    (fun posts ->
      render_app app_el (Shared.Posts_page (Shared.Ready posts)))
    (fun err ->
      render_app app_el (Shared.Posts_page (Shared.Error ("Failed to load posts: " ^ err))))

let render_users_page app_el =
  Dom.log "Rendering users page...";
  render_app app_el (Shared.Users_page Shared.Loading);
  fetch_users
    (fun users ->
      render_app app_el (Shared.Users_page (Shared.Ready users)))
    (fun err ->
      render_app app_el (Shared.Users_page (Shared.Error ("Failed to load users: " ^ err))))

let render_user_page app_el user_id =
  Dom.log ("Rendering user page for ID: " ^ string_of_int user_id);
  render_app app_el (Shared.User_page (Shared.Loading, Shared.Loading));
  fetch_user user_id
    (fun user ->
      render_app app_el (Shared.User_page (Shared.Ready user, Shared.Loading)))
    (fun err ->
      render_app app_el (Shared.User_page (Shared.Error ("Failed to load user: " ^ err), Shared.Loading)));
  fetch_user_posts user_id
    (fun posts ->
      render_app app_el (Shared.User_page (Shared.Loading, Shared.Ready posts)))
    (fun err ->
      render_app app_el (Shared.User_page (Shared.Loading, Shared.Error ("Failed to load posts: " ^ err))))

let render_post_page app_el post_id =
  Dom.log ("Rendering post page for ID: " ^ string_of_int post_id);
  render_app app_el (Shared.Post_page (Shared.Loading, Shared.Loading));
  fetch_post post_id
    (fun post ->
      render_app app_el (Shared.Post_page (Shared.Ready post, Shared.Loading)))
    (fun err ->
      render_app app_el (Shared.Post_page (Shared.Error ("Failed to load post: " ^ err), Shared.Loading)));
  fetch_comments post_id
    (fun comments ->
      render_app app_el (Shared.Post_page (Shared.Loading, Shared.Ready comments)))
    (fun err ->
      render_app app_el (Shared.Post_page (Shared.Loading, Shared.Error ("Failed to load comments: " ^ err))))

let render_page path =
  Dom.log ("Rendering page: " ^ path);
  match get_element "app" with
  | None -> Dom.log "Error: #app element not found"
  | Some app_el ->
    if path = "/" then
      render_posts_page app_el
    else if path = "/users" then
      render_users_page app_el
    else if String.length path > 7 && String.sub path 0 7 = "/posts/" then
      let id_str = String.sub path 7 (String.length path - 7) in
      (match int_of_string_opt id_str with
       | Some id -> render_post_page app_el id
       | None -> render_app app_el (Shared.Not_found "Invalid post ID"))
    else if String.length path > 7 && String.sub path 0 7 = "/users/" then
      let id_str = String.sub path 7 (String.length path - 7) in
      (match int_of_string_opt id_str with
       | Some id -> render_user_page app_el id
       | None -> render_app app_el (Shared.Not_found "Invalid user ID"))
    else
      render_app app_el (Shared.Not_found ("Page not found: " ^ path))

(** {1 Navigation Helpers} *)

let setup_links () =
  let links = query_selector_all "a[href]" in
  List.iter (fun link ->
    match Dom.get_attribute link "data-setup" with
    | Some _ -> ()
    | None ->
      Dom.set_attribute link "data-setup" "true";
      Dom.add_event_listener link "click" (fun evt ->
        match Dom.get_attribute link "href" with
        | Some href when String.length href > 0 && href.[0] = '/' ->
          Dom.prevent_default evt;
          Dom.push_state href;
          current_path := href;
          render_page href
        | _ -> ())
  ) links

let setup_navigation () =
  Dom.on_popstate (fun _evt ->
    let path = Dom.get_pathname () in
    current_path := path;
    render_page path
  );
  setup_links ()

(** {1 Main Entry Point} *)

let () =
  let (_result, _dispose) = Reactive_core.create_root (fun () ->
    let path = Dom.get_pathname () in
    current_path := path;
    setup_navigation ();
    render_page path
  ) in
  ()

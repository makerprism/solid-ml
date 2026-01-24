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
module Routes = Ssr_api_shared.Routes
module Api = Api_client
module Async = Ssr_api_shared.Async
module Api_error = Ssr_api_shared.Error

type user_info = Shared.user_info
type post = Shared.post
type comment = Shared.comment

(** {1 DOM Helpers} *)

let get_element id = Dom.get_element_by_id (Dom.document ()) id

(** {1 Rendering} *)

let current_path = ref "/"

let rec render_app app_el page =
  let _dispose = Render.render app_el (fun () ->
    C.app ~current_path:!current_path ~page ()
  ) in
  bind_links app_el

and bind_links app_el =
  let _dispose =
    Navigation.bind_links ~root:app_el ~on_navigate:(fun href ->
      current_path := href;
      render_page href
    ) ()
  in
  ()

and render_posts_page app_el =
  Dom.log "Rendering posts page...";
  render_app app_el (Shared.Posts_page (Shared.Loading, None));
  Async.run (Api.fetch_posts ())
    ~ok:(fun posts ->
      Async.run (Api.fetch_users ())
        ~ok:(fun users ->
          render_app app_el (Shared.Posts_page (Shared.Ready posts, Some users)))
        ~err:(fun _err ->
          render_app app_el (Shared.Posts_page (Shared.Ready posts, None))))
    ~err:(fun err ->
      render_app app_el (Shared.Posts_page
        (Shared.Error ("Failed to load posts: " ^ Api_error.to_string err), None)))

and render_users_page app_el =
  Dom.log "Rendering users page...";
  render_app app_el (Shared.Users_page Shared.Loading);
  Async.run (Api.fetch_users ())
    ~ok:(fun users ->
      render_app app_el (Shared.Users_page (Shared.Ready users)))
    ~err:(fun err ->
      render_app app_el
        (Shared.Users_page (Shared.Error ("Failed to load users: " ^ Api_error.to_string err))))

and render_user_page app_el user_id =
  Dom.log ("Rendering user page for ID: " ^ string_of_int user_id);
  render_app app_el (Shared.User_page (Shared.Loading, Shared.Loading));
  Async.run (Api.fetch_user user_id)
    ~ok:(fun user ->
      render_app app_el (Shared.User_page (Shared.Ready user, Shared.Loading));
      Async.run (Api.fetch_user_posts user_id)
        ~ok:(fun posts ->
          render_app app_el (Shared.User_page (Shared.Ready user, Shared.Ready posts)))
        ~err:(fun err ->
          render_app app_el
            (Shared.User_page
              (Shared.Ready user,
               Shared.Error ("Failed to load posts: " ^ Api_error.to_string err)))))
    ~err:(fun err ->
      let message = Api_error.to_string err in
      render_app app_el (Shared.User_page (Shared.Error ("Failed to load user: " ^ message), Shared.Loading));
      Async.run (Api.fetch_user_posts user_id)
        ~ok:(fun posts ->
          render_app app_el
            (Shared.User_page
              (Shared.Error ("Failed to load user: " ^ message), Shared.Ready posts)))
        ~err:(fun err2 ->
          render_app app_el
            (Shared.User_page
              (Shared.Error ("Failed to load user: " ^ message),
               Shared.Error ("Failed to load posts: " ^ Api_error.to_string err2)))))

and render_post_page app_el post_id =
  Dom.log ("Rendering post page for ID: " ^ string_of_int post_id);
  render_app app_el (Shared.Post_page (Shared.Loading, Shared.Loading));
  Async.run (Api.fetch_post post_id)
    ~ok:(fun post ->
      render_app app_el (Shared.Post_page (Shared.Ready post, Shared.Loading));
      Async.run (Api.fetch_comments post_id)
        ~ok:(fun comments ->
          render_app app_el (Shared.Post_page (Shared.Ready post, Shared.Ready comments)))
        ~err:(fun err ->
          render_app app_el
            (Shared.Post_page
              (Shared.Ready post,
               Shared.Error ("Failed to load comments: " ^ Api_error.to_string err)))))
    ~err:(fun err ->
      let message = Api_error.to_string err in
      render_app app_el (Shared.Post_page (Shared.Error ("Failed to load post: " ^ message), Shared.Loading));
      Async.run (Api.fetch_comments post_id)
        ~ok:(fun comments ->
          render_app app_el
            (Shared.Post_page
              (Shared.Error ("Failed to load post: " ^ message), Shared.Ready comments)))
        ~err:(fun err2 ->
          render_app app_el
            (Shared.Post_page
              (Shared.Error ("Failed to load post: " ^ message),
               Shared.Error ("Failed to load comments: " ^ Api_error.to_string err2)))))

and render_page path =
  Dom.log ("Rendering page: " ^ path);
  match get_element "app" with
  | None -> Dom.log "Error: #app element not found"
  | Some app_el ->
    match Routes.of_path path with
    | Some Routes.Posts -> render_posts_page app_el
    | Some Routes.Users -> render_users_page app_el
    | Some (Routes.Post id) -> render_post_page app_el id
    | Some (Routes.User id) -> render_user_page app_el id
    | None -> render_app app_el (Shared.Not_found ("Page not found: " ^ path))

(** {1 Main Entry Point} *)

let () =
  let (_result, _dispose) = Reactive_core.create_root (fun () ->
    let path = Dom.get_pathname () in
    current_path := path;
     (match get_element "app" with
      | None -> Dom.log "Error: #app element not found"
      | Some _ ->
        let _dispose =
          Navigation.bind_popstate ~on_navigate:(fun next_path ->
            current_path := next_path;
            render_page next_path
          ) ()
        in
        render_page path)
  ) in
  ()

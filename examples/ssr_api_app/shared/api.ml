let api_base = ref "https://jsonplaceholder.typicode.com"

module type Fetch = sig
  module Async : Async.S
  val get : string -> string Async.t
end

module Make (Fetch : Fetch) (Json : Json_intf.S) = struct
  module Async = Fetch.Async
  module Decode = Decode.Make (Json)

  let build_url path =
    !api_base ^ path

  let decode_with decode json =
    match decode json with
    | Ok value -> Async.return value
    | Error err -> Async.fail err

  let fetch path decode =
    let open Async in
    Fetch.get (build_url path)
    |> bind (fun body ->
      match Json.parse body with
      | Ok json -> decode_with decode json
      | Error err -> fail err)

  let fetch_users () =
    fetch "/users" Decode.users

  let fetch_user id =
    fetch ("/users/" ^ string_of_int id) Decode.user

  let fetch_posts () =
    fetch "/posts?_limit=50" Decode.posts

  let fetch_user_posts user_id =
    fetch ("/users/" ^ string_of_int user_id ^ "/posts") Decode.posts

  let fetch_post id =
    fetch ("/posts/" ^ string_of_int id) Decode.post

  let fetch_comments post_id =
    fetch ("/posts/" ^ string_of_int post_id ^ "/comments") Decode.comments
end

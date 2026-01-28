module Async = Ssr_api_shared.Async

module Fetch = struct
  module Async = Ssr_api_shared.Async
  let get = Fetch_client.get
end

module Api = Ssr_api_shared.Api.Make (Fetch) (Json_client)

let fetch_users = Api.fetch_users
let fetch_user = Api.fetch_user
let fetch_posts = Api.fetch_posts
let fetch_user_posts = Api.fetch_user_posts
let fetch_post = Api.fetch_post
let fetch_comments = Api.fetch_comments

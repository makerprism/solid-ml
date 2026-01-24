module Async = Ssr_api_shared.Async

module Fetch = struct
  module Async = Async
  let get = Fetch_server.get
end

module Api = Ssr_api_shared.Api.Make (Fetch) (Json_server)

let to_lwt value =
  let waiter, wakener = Lwt.wait () in
  Async.run value
    ~ok:(fun v -> Lwt.wakeup_later wakener (Ok v))
    ~err:(fun e -> Lwt.wakeup_later wakener (Error e));
  waiter

let fetch_users () = to_lwt (Api.fetch_users ())
let fetch_user id = to_lwt (Api.fetch_user id)
let fetch_posts () = to_lwt (Api.fetch_posts ())
let fetch_user_posts id = to_lwt (Api.fetch_user_posts id)
let fetch_post id = to_lwt (Api.fetch_post id)
let fetch_comments id = to_lwt (Api.fetch_comments id)

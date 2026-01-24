module Async = Ssr_api_shared.Async

module Fetch = struct
  module Async = Async
  let get = Fetch_client.get
end

module Api = Ssr_api_shared.Api.Make (Fetch) (Json_client)

include Api

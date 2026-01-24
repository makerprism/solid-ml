module Async = Ssr_api_shared.Async
module Error = Ssr_api_shared.Error

let get url : string Async.t =
  fun ~ok ~err ->
    let task =
      Lwt.wrap (fun () ->
        try
          let handle = Curl.init () in
          Curl.set_url handle url;
          let buffer = Buffer.create 1024 in
          Curl.set_writefunction handle (fun data ->
            Buffer.add_string buffer data;
            String.length data
          );
          Curl.perform handle;
          let code = Curl.get_httpcode handle in
          Curl.cleanup handle;
          if code >= 200 && code < 300 then
            Ok (Buffer.contents buffer)
          else
            Error (Error.Http_error code)
        with
        | Curl.CurlException (_, _, msg) ->
            Error (Error.Network_error msg)
        | exn ->
            Error (Error.Network_error (Printexc.to_string exn))
      )
      |> Lwt.map (function
        | Ok body -> ok body
        | Error e -> err e)
    in
    Lwt.async (fun () -> task);
    ()

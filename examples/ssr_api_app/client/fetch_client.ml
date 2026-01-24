module Async = Ssr_api_shared.Async
module Error = Ssr_api_shared.Error

external fetch_raw : string -> (string -> unit) -> (int -> string -> unit) -> unit
  = [%mel.raw {|
    function(url, onOk, onErr) {
      fetch(url)
        .then(function(resp) {
          if (!resp.ok) {
            onErr(resp.status || 0, "HTTP " + resp.status);
            return null;
          }
          return resp.text();
        })
        .then(function(text) {
          if (text !== null) {
            onOk(text);
          }
        })
        .catch(function(err) {
          var message = (err && err.message) ? err.message : "Fetch failed";
          onErr(0, message);
        });
    }
  |}]

let get url : string Async.t =
  fun ~ok ~err ->
    fetch_raw url
      (fun body -> ok body)
      (fun status message ->
        if status > 0 then
          err (Error.Http_error status)
        else
          err (Error.Network_error message))

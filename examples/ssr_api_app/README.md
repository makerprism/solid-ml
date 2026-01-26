# SSR API App Example

This example demonstrates server-side rendering with client hydration and a
shared API module. The browser entrypoint uses `Render.hydrate` for the first
paint to adopt the server HTML before switching to client-side renders. It now
supports typed Resource errors, so you can define a single error type and reuse
it across server and client.

## Typed Resource Example (Browser)

```ocaml
open Solid_ml_browser
module Api = Api_client

type api_error =
  | Fetch_failed of string
  | Not_found of string

let api_error_to_string = function
  | Fetch_failed msg -> "Fetch failed: " ^ msg
  | Not_found msg -> "Not found: " ^ msg

let users_resource =
  Resource.create_async_with_error
    ~on_error:(fun exn -> Fetch_failed (Dom.exn_to_string exn))
    (fun set_result ->
      Ssr_api_shared.Async.run (Api.fetch_users ())
        ~ok:(fun users -> set_result (Ok users))
        ~err:(fun _ -> set_result (Error (Fetch_failed "API error")))
    )

let users_view () =
  Resource.render
    ~loading:(fun () -> Html.text "Loading...")
    ~error:(fun err -> Html.text (api_error_to_string err))
    ~ready:(fun users -> Html.text (string_of_int (List.length users)))
    users_resource
```

Use the same error type with `Resource.read_suspense` or `Resource.get` by
providing `~error_to_string`.

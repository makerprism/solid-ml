# Full SSR App

This example shows end-to-end server-side rendering with client hydration.

## Hydration State

The server embeds initial state using `Solid_ml_ssr.State`. Use namespaced keys
to avoid collisions and encode values explicitly.

```ocaml
let counter_key = Solid_ml_ssr.State.key ~namespace:"full_ssr" "counter" in
Solid_ml_ssr.State.set_encoded
  ~key:counter_key
  ~encode:Solid_ml_ssr.State.encode_int
  initial
```

On the client, hydrate the component using the same key. Use `~revalidate:true`
to refresh resources after hydration.

```ocaml
let counter_key = Solid_ml_browser.State.key ~namespace:"full_ssr" "counter" in
let counter =
  Solid_ml_browser.State.decode
    ~key:counter_key
    ~decode:decode_int
    ~default:0

let resource =
  Solid_ml_browser.Resource.create_with_hydration
    ~key:(Solid_ml_browser.State.key ~namespace:"full_ssr" "user")
    ~decode:decode_user
    ~revalidate:true
    fetch_user
```

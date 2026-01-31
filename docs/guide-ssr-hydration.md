# SSR + Hydration Guide

This guide covers SSR rendering, hydration, and state transfer.

## SSR Rendering

```ocaml
let html = Solid_ml_ssr.Render.to_document (fun () ->
  my_component ()
)
```

## State Transfer

Server-side encode:

```ocaml
let key = Solid_ml_ssr.State.key ~namespace:"app" "counter" in
Solid_ml_ssr.State.set_encoded
  ~key
  ~encode:Solid_ml_ssr.State.encode_int
  42
```

Client-side decode:

```ocaml
let key = Solid_ml_browser.State.key ~namespace:"app" "counter" in
let initial =
  Solid_ml_browser.State.decode
    ~key
    ~decode:(fun json ->
      Js.Json.decodeNumber json |> Option.map int_of_float)
    ~default:0
```

## Resource Hydration

```ocaml
let resource =
  Solid_ml_browser.Resource.create_with_hydration
    ~key:(Solid_ml_browser.State.key ~namespace:"app" "user")
    ~decode:decode_user
    ~revalidate:true
    fetch_user
```

## Hydrate on the Client

```ocaml
match Solid_ml_browser.Dom.get_element_by_id (Solid_ml_browser.Dom.document ()) "app" with
| Some root ->
  let _dispose = Solid_ml_browser.Render.hydrate root (fun () -> my_component ()) in
  ()
| None -> ()
```

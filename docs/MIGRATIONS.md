# Migrations (pre-release)

All releases before 1.0 may introduce breaking changes. This file lists
common migrations for recent changes.

## Router SSR helpers

Old:

```ocaml
open Solid_ml_router

let node = Components.link ~href:"/about" ~children:[Html.text "About"] ()
```

New:

```ocaml
open Solid_ml_ssr

let node = Router_components.link ~href:"/about" ~children:[Html.text "About"] ()
```

`Solid_ml_router.Components` is now a functor only. Use
`Solid_ml_ssr.Router_components` for SSR defaults.

## Resource state rename

`Pending` is deprecated and treated as loading. Use `Loading/Ready/Error`.

## Derived resources are read-only

Resources returned by `map`, `combine`, and `combine_all` are derived and
read-only. Their actions are no-ops (except `refetch`, which forwards to
source resources).

## Async Resource API

For callback-style async creation, use `Resource.Async`:

```ocaml
let resource = Resource.Async.create (fun set_result ->
  fetch (fun response ->
    match response with
    | Ok data -> set_result (Ok data)
    | Error err -> set_result (Error err))
)
```

`Resource.create_async_with_error` is still available in router/browser
for legacy `~ok/~error` or result-callback forms.

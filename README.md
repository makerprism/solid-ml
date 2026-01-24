# solid-ml

An OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by [SolidJS](https://www.solidjs.com/).

> **Status:** All phases complete! ✅ Reactive core, SSR, client runtime, router, Suspense/ErrorBoundary, event replay, and resource hydration are ready. 210 tests passing.

## ⚠️ Development Status

**Started:** January 5, 2026 (5 days of intensive development)

**Maturity:** Experimental - Not battle-tested in production yet.

solid-ml is a mostly faithful port of SolidJS to OCaml, enabling full-stack OCaml web applications where validation logic, types, and business logic can be seamlessly shared between server and client. While all core features are implemented with comprehensive test coverage (210 tests), solid-ml has **not been used in production** and may have undiscovered edge cases.

Expect rapid iteration, breaking changes, and active development. **Use at your own risk.** If you're adventurous and want to help stabilize it, contributions and feedback are welcome!

## Features

- **Fine-grained reactivity** - Signals, effects, and memos with automatic dependency tracking
- **Server-side rendering** - Full HTML rendering for SEO and fast first paint  
- **Client-side hydration** - Seamless hydration and reactive DOM updates via Melange
- **SSR-aware routing** - Router with data loaders, navigation, and active link tracking
- **Suspense & Error Boundaries** - Async loading states and error handling
- **Thread-safe** - Domain-local storage enables safe parallel execution (OCaml 5)
- **Type-safe** - Full OCaml type checking for your UI
- **SolidJS-compatible** - Familiar API for SolidJS developers
- **Event replay** - Pre-hydration interactions are captured and replayed on client
- **Resource hydration** - Serialize and hydrate async resources from server to client

## Changelog

See `CHANGES.md` for unreleased and release notes.

## Quick Start

```ocaml
open Solid_ml

let () =
  Runtime.run (fun token ->
    let dispose =
      Owner.create_root token (fun () ->
        (* Create a signal (reactive value) *)
        let count, set_count = Signal.create token 0 in

        (* Create a memo (derived value) *)
        let doubled = Memo.create token (fun () ->
          Signal.get count * 2
        ) in

        (* Create an effect (side effect that re-runs when dependencies change) *)
        Effect.create token (fun () ->
          Printf.printf "Count: %d, Doubled: %d\n"
            (Signal.get count)
            (Memo.get doubled)
        );

        (* Update the signal - effect automatically re-runs *)
        set_count 1;  (* prints: Count:1, Doubled: 2 *)
        set_count 2   (* prints: Count:2, Doubled: 4 *)
      )
    in
    dispose ()
  )
```

## Core API

### Runtime Tokens (Strict by Default)

All reactive code must run within a `Runtime.run` context. It hands you a
`token` that must be threaded into signal/effect/memo creation. This is a
compile-time guardrail that prevents accidental use of reactivity outside a
runtime. Do not stash tokens globally or across runtimes.

```ocaml
(* Create isolated reactive context *)
Runtime.run (fun token ->
  (* Reactive code here *)
  let _count, _set_count = Signal.create token 0
  ()
)

(* If you need legacy API, use explicit `Unsafe` modules (e.g.
`Signal.Unafe.create`). This is intentionally opt-in. Avoid `Obj.magic`.
```

SSR helpers like `Solid_ml_ssr.Render.to_string` create and dispose a runtime
internally and therefore do not expose a token. Prefer strict APIs in app code,
and only rely on `Unsafe` modules when integrating with those helpers.

For less token plumbing, you can use the scoped helper to bind a token once:

```ocaml
Scoped.run (fun (module R) ->
  let count, set_count = R.Signal.create 0 in
  R.Effect.create (fun () ->
    Printf.printf "Count: %d\n" (R.Signal.get count)
  );
  set_count 1
)
```

### Signals

```ocaml
(* Assume [token] comes from Runtime.run *)
(* Create a signal with initial value (uses structural equality by default) *)
let count, set_count = Signal.create token 0

(* Create with physical equality (for mutable values) *)
let buffer, set_buffer = Signal.create_physical token (Bytes.create 100)

(* Create with custom equality *)
let items, set_items = Signal.create_eq
  ~equals:(fun a b -> List.length a = List.length b) 
  []
(* Read value (tracks dependency in effects/memos) *)
let value = Signal.get count

(* Read without tracking *)
let value = Signal.peek count

(* Update value - only notifies if value changed *)
Signal.set count 42
Signal.update count (fun n -> n + 1)
```

### Effects

```ocaml
(* Assume [token] comes from Runtime.run *)
(* Effect re-runs when any signal it reads changes *)
Effect.create token (fun () ->
  print_endline (string_of_int (Signal.get count))
)

(* Effect with cleanup *)
Effect.create_with_cleanup token (fun () ->
  let subscription = subscribe_something () in
  fun () -> unsubscribe subscription
)

(* Read signal without tracking *)
let value = Effect.untrack (fun () -> Signal.get some_signal)
```

### Memos

```ocaml
(* Assume [token] comes from Runtime.run *)
(* Memo caches derived value, only recomputes when deps change *)
let doubled = Memo.create token (fun () ->
  Signal.get count * 2
)

(* Read memo like a signal *)
let value = Memo.get doubled
```

### Batch

```ocaml
(* Assume [token] comes from Runtime.run *)
(* Batch multiple updates, effects run once at end *)
Batch.run token (fun () ->
  Signal.set first_name "John";
  Signal.set last_name "Doe"
)
```

### Owner (Cleanup/Disposal)

```ocaml
(* Assume [token] comes from Runtime.run *)
(* Create a root that owns effects - dispose cleans everything up *)
let dispose = Owner.create_root token (fun () ->
  Effect.create token (fun () -> ...)
) in
dispose ()  (* All effects inside are disposed *)

(* Register cleanup with current owner *)
Owner.on_cleanup (fun () ->
  print_endline "Cleaning up!"
)
```

### Context

```ocaml
(* Create a context with default value *)
let theme_context = Context.create "light"

(* Provide value to descendants *)
Context.provide theme_context "dark" (fun () ->
  (* Code here sees "dark" *)
  let theme = Context.use theme_context in
  ...
)
)
```

### Suspense & Error Boundaries

```ocaml
(* Suspense boundary for async loading states *)
let ui = Suspense.boundary
  ~fallback:(fun () -> [Html.div [] [Html.text "Loading..."]])
  ~children:(fun () ->
    let data =
      Resource.read_suspense
        ~default:[]
        ~error_to_string:(fun err -> err)
        my_resource
    in
    [Html.div [] (List.map render_item data)]
  )

(* Error boundary for catching errors *)
let ui = ErrorBoundary.make
  ~fallback:(fun error reset ->
    [Html.div [] [
      Html.text ("Error: " ^ error);
      Html.button [Html.on_click (fun _ -> reset ())] 
        [Html.text "Retry"]
    ]]
  )
  ~children:(fun () ->
    (* Code that might throw *)
    [Html.div [] [Html.text "Success!"]]
  )
```

### Resource Errors (Typed)

Resources can carry a custom error type. Use `create_async_with_error` to map
exceptions into your error type and provide an `error_to_string` when rendering
or when converting errors to exceptions (e.g. `read_suspense`, `get`).

Browser-side async resources follow the same pattern:

```ocaml
let user_resource =
  Solid_ml_browser.Resource.create_async_with_error
    ~on_error:(fun exn -> Fetch_error (Solid_ml_browser.Dom.exn_to_string exn))
    (fun set_result ->
      Fetch.get "/api/user/123" (fun response ->
        match response with
        | Ok data -> set_result (Ok data)
        | Error _ -> set_result (Error (User_not_found "123"))
      )
    )
```

If you want a reusable error shape, define a small domain error type and a
single `to_string` helper:

```ocaml
type api_error =
  | Http_error of int
  | Json_error of string
  | Network_error of string

let api_error_to_string = function
  | Http_error code -> "HTTP " ^ string_of_int code
  | Json_error msg -> "JSON error: " ^ msg
  | Network_error msg -> "Network error: " ^ msg
```

### Migration Notes (Typed Resource Errors)

If you're upgrading from the string-only Resource API:

- `Resource.Error` now carries your error type instead of `string`.
- `Resource.read_suspense` and `Resource.get` accept `~error_to_string` to
  convert typed errors into messages.
- Use `create_with_error` / `create_async_with_error` to map exceptions into
  your error type.

### Release Notes (Unreleased)

- Typed Resource errors across `solid-ml`, `solid-ml-router`, and
  `solid-ml-browser` with opt-in error formatting helpers.

```ocaml
type user_error =
  | User_not_found of string
  | Fetch_error of string

let user_error_to_string = function
  | User_not_found username -> "User not found: " ^ username
  | Fetch_error msg -> "Failed to load user: " ^ msg

let user_resource username =
  Resource.create_async_with_error
    ~on_error:(fun exn -> Fetch_error (Printexc.to_string exn))
    (fun ~ok ~error ->
      match Api.fetch_user username with
      | Ok user -> ok user
      | Error _ -> error (User_not_found username)
    )

let view_user username () =
  let resource = user_resource username in
  Resource.render
    ~loading:(fun () -> Html.text "Loading...")
    ~error:(fun err -> Html.text (user_error_to_string err))
    ~ready:(fun user -> Html.text user.name)
    resource
```

### Router (SSR-aware)

solid-ml has comprehensive test coverage:

- **31 tests** - Reactive core (signals, effects, memos, batching)
- **23 tests** - HTML rendering and SSR
- **36 tests** - SolidJS compatibility
- **91 tests** - Router (matching, navigation, data loading)
- **14 tests** - Browser reactive core
- **13 tests** - Suspense and ErrorBoundary
- **18 tests** - Browser DOM + template rendering

**Total: 210 tests** across all packages.

Run tests with:
```bash
dune runtest          # Native OCaml tests
make browser-tests    # Browser tests via Node.js
make browser-tests-headless # Browser DOM tests (headless Chrome)
```

## Building

```bash
# Build all packages
dune build

# Run tests
dune runtest
```

### Dune Package Management

This project uses **dune package management** with dune installed at `/usr/bin/dune`. All build commands (via Makefile or direct dune invocation) use this fixed path by default.

**Why `/usr/bin/dune`?** This project was configured to use a system-installed dune at `/usr/bin/dune` to avoid issues with opam switch environments, where different dune versions from different switches could be inadvertently picked up. This ensures consistent builds across development environments.

**Override dune location:** If your dune is installed elsewhere, you can override to default using a `DUNE` environment variable:

```bash
make DUNE=/custom/path/to/dune build
make DUNE=/custom/path/to/dune test
# Or set it globally:
export DUNE=/custom/path/to/dune
make build
```

## Requirements

- **OCaml 5.0+** (uses Domain-local storage for thread safety)
- **dune 3.16+** with Melange support (`(using melange 0.1)`)
- **For browser builds:** Node.js (for esbuild bundling)
- **For web server examples:** Dream (not included - see examples for reference code)

## Installation

### Via Dune Package Management (Git)

Add to your `dune-project`:

```scheme
(package
  (name my-app)
  (depends
   (solid-ml (>= 0.1.0))
   (solid-ml-ssr (>= 0.1.0))
   (solid-ml-router (>= 0.1.0))))  ; Optional

(source
  (github makerprism/solid-ml))
```

Then run:
```bash
dune pkg lock
dune build
```

### Via OPAM Pin (Development)

```bash
opam pin add solid-ml.0.1.0 git+https://github.com/makerprism/solid-ml#main
opam pin add solid-ml-ssr.0.1.0 git+https://github.com/makerprism/solid-ml#main
opam pin add solid-ml-router.0.1.0 git+https://github.com/makerprism/solid-ml#main
```

### Via OPAM (Coming Soon)

```bash
opam install solid-ml solid-ml-ssr solid-ml-router
```

## Architecture & Design

solid-ml uses a **functor-based architecture** to share reactive algorithms between server and browser:

- **`solid-ml-internal`**: Core reactive functor (platform-agnostic)
- **`solid-ml`**: Server instantiation with Domain-local storage (thread-safe)
- **`solid-ml-browser`**: Browser instantiation with global ref (single-threaded JS)

This design allows the same reactive code to run on both server (for SSR) and client (for hydration).

### Key Design Choices

- **Fine-grained updates**: No virtual DOM diffing - signals update only their subscribers
- **Automatic dependency tracking**: Reading a signal inside an effect/memo auto-subscribes
- **Eager memos**: Like SolidJS, memos compute immediately (not lazy)
- **Type safety via phantom types**: Internal `Obj.t` for heterogeneous collections, safe typed API
- **SSR-first**: Components render to HTML strings, client hydrates existing DOM

### Important Constraints

- **Signals cannot be shared across runtimes/domains** (by design for thread safety)
- **Always dispose `Owner.create_root`** to prevent memory leaks
- **`Render.to_string` handles disposal automatically**
- **No async in effects** - fetch data before entering reactive context (use Resources in router)

For detailed limitations and workarounds, see [LIMITATIONS.md](LIMITATIONS.md).

## SSR Hydration Data

You can embed server state for hydration using `Solid_ml_ssr.State`. Keys can be
namespaced with `State.key` and values should be encoded explicitly.

```ocaml
let key = Solid_ml_ssr.State.key ~namespace:"todos" "list" in
Solid_ml_ssr.State.set_encoded ~key ~encode:Solid_ml_ssr.State.encode_string "ok"
```

For resources, serialize their state explicitly on the server and hydrate on the client. You can also request a background refresh with `~revalidate:true`.

```ocaml
Solid_ml_ssr.Resource_state.set
  ~key:"user"
  ~encode:Solid_ml_ssr.State.encode_string resource

let resource =
  Solid_ml_browser.Resource.create_with_hydration
    ~key:"user"
    ~decode:Js.Json.decodeString
    ~revalidate:true
    fetch_user
```

## Examples

### Native OCaml Examples

```bash
# Counter - reactive primitives demo
make example-parallel

# Todo list - list operations and SSR rendering
make example-counter
```

### Web Server Examples (require Dream)

```bash
# SSR server with routing (requires dream)
make example-ssr-server

# Full SSR app with hydration (requires dream)
make example-full-ssr
# SSR API app demo (requires dream)
make example-ssr-api
```

### Browser Examples (require Node.js for esbuild)

```bash
# Build all browser examples
make browser-examples

# Serve and open http://localhost:8000
make serve
```

### Browser Examples

- **browser_counter** - Browser counter with client-side reactivity
- **browser_router** - Browser router with client-side navigation
- **template_counter** - Template compiler counter example
- **full_ssr_app** - Full SSR + hydration demo with state serialization and resource hydration

## Browser DOM Tests

The DOM integration tests compile to JavaScript and run in a real browser.

```bash
# Build + run headless (requires Chrome)
make browser-tests-headless

# Or compile and open manually
dune build @test_browser_dom/melange
```

For manual runs, open `test_browser_dom/runner.html` in a browser and confirm
`data-test-result` attribute shows `PASS`.

## Documentation

- **[AGENTS.md](AGENTS.md)** - Development guidelines and project structure
- **[LIMITATIONS.md](LIMITATIONS.md)** - Known limitations and workarounds
- **[docs/A-01-architecture.md](docs/A-01-architecture.md)** - Full architecture document

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: Reactive Core | ✅ Complete | Signals, effects, memos, batching, ownership, context |
| Phase 2: Server Rendering | ✅ Complete | HTML generation, SSR, hydration markers |
| Phase 3: Client Runtime | ✅ Complete | DOM bindings, hydration, reactive updates via Melange |
| Phase 4: Router | ✅ Complete | Route matching, navigation, data loaders, SSR support |
| Phase 5: Suspense | ✅ Complete | Async boundaries, error handling, unique IDs |
| **Event Replay** | ✅ Complete | Pre-hydration interactions captured and replayed |
| **Resource Hydration** | ✅ Complete | State serialization and async resource hydration |

All core features are implemented and tested. **Ready for experimental use** - waiting for real-world validation.

## Contributing

solid-ml is a collaborative project. Contributions are welcome! Please see [AGENTS.md](AGENTS.md) for development guidelines.

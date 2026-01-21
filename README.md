# solid-ml

An OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by [SolidJS](https://www.solidjs.com/).

> **Status:** All phases complete! ✅ Reactive core, SSR, client runtime, router, and Suspense/ErrorBoundary are ready. 124 tests passing.

## ⚠️ Development Status

**Started:** January 5, 2026 (2 days of intensive development)

**Maturity:** Experimental - Not battle-tested in production yet.

solid-ml is a mostly faithful port of SolidJS to OCaml, enabling full-stack OCaml web applications where validation logic, types, and business logic can be seamlessly shared between server and client. While all core features are implemented with comprehensive test coverage (208 tests), solid-ml has **not been used in production** and may have undiscovered edge cases.

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
        set_count 1;  (* prints: Count: 1, Doubled: 2 *)
        set_count 2   (* prints: Count: 2, Doubled: 4 *)
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
  let _count, _set_count = Signal.create token 0 in
  ()
)
```

If you need the legacy API, use explicit `Unsafe` modules (e.g.
`Signal.Unsafe.create`). This is intentionally opt-in. Avoid `Obj.magic`.

SSR helpers like `Solid_ml_ssr.Render.to_string` create and dispose a runtime
internally and therefore do not expose a token. Prefer strict APIs in app code,
and only rely on `Unsafe` modules when integrating with those helpers.

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
```

### Suspense & Error Boundaries

```ocaml
(* Suspense boundary for async loading states *)
let ui = Suspense.boundary
  ~fallback:(fun () -> [Html.div [] [Html.text "Loading..."]])
  ~children:(fun () ->
    let data = Resource.read_suspense my_resource ~default:[] in
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

### Router (SSR-aware)

```ocaml
open Solid_ml_router

(* Define routes *)
let routes = [
  Route.make "/" (fun _ -> home_page ());
  Route.make "/users/:id" (fun params ->
    let id = List.assoc "id" params in
    user_page id
  );
]

(* Server-side: render with initial URL *)
let html = Router.render_to_string routes "/users/123"

(* Browser-side: hydrate with client-side navigation *)
let () = Router.hydrate routes (Dom.get_element_by_id "app")
```

## Thread Safety

solid-ml uses OCaml 5's Domain-local storage for thread safety:

- Each domain has independent runtime state
- Safe for parallel execution with `Domain.spawn`
- Each Dream request can run in its own runtime

```ocaml
(* Parallel rendering across domains *)
let results = Array.init 4 (fun _ ->
  Domain.spawn (fun () ->
    Runtime.run (fun token ->
      let count, _set_count = Signal.create token 0 in
      Signal.get count
    )
  )
) |> Array.map Domain.join
```

**Important**: Signals should not be shared across runtimes or domains. Each runtime maintains its own reactive graph.

## Packages

| Package | Description | Status |
|---------|-------------|--------|
| `solid-ml-internal` | Shared functor-based reactive core | ✅ Complete |
| `solid-ml` | Server-side reactive framework (OCaml 5 + DLS) | ✅ Complete |
| `solid-ml-ssr` | Server-side rendering to HTML strings | ✅ Complete |
| `solid-ml-browser` | Client-side rendering and hydration (Melange) | ✅ Complete |
| `solid-ml-router` | SSR-aware routing with data loaders | ✅ Complete |

**Note:** `solid-ml-browser` requires Melange 3.0+ for building client-side code.

## Examples

### Native OCaml Examples

```bash
# Counter - reactive primitives demo
dune exec examples/counter/counter.exe

# Todo list - list operations and SSR
dune exec examples/todo/todo.exe

# Router - routing with params and navigation
dune exec examples/router/router.exe

# Parallel rendering - OCaml 5 domain safety
dune exec examples/parallel/parallel.exe
```

### Web Server Examples (require Dream)

The SSR server examples require Dream and are disabled by default to keep the core library dependencies minimal.

```bash
# SSR server with routing (requires dream)
dune exec examples/ssr_server/server.exe

# Full SSR app with hydration (requires dream)
make example-full-ssr

# SSR API demo (requires dream)
make example-ssr-api
```

### Browser Examples

```bash
# Build browser examples
make browser-examples

# Serve and open http://localhost:8000
make serve
```

See also:
- `examples/browser_counter/` - Browser counter with client-side reactivity
- `examples/browser_router/` - Browser router with client-side navigation
- `examples/js_framework_benchmark/` - JS Framework Benchmark
```

## Building

```bash
# Build all packages
dune build

# Run tests
dune runtest
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

## Testing

solid-ml has comprehensive test coverage:

- **31 tests** - Reactive core (signals, effects, memos, batching)
- **23 tests** - HTML rendering and SSR
- **36 tests** - SolidJS compatibility 
- **91 tests** - Router (matching, navigation, data loading)
- **14 tests** - Browser reactive core
- **13 tests** - Suspense and ErrorBoundary

**Total: 208 tests** across all packages.

Run tests with:
```bash
dune runtest          # Native OCaml tests
make browser-tests    # Browser tests via Node.js
```

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: Reactive Core | ✅ Complete | Signals, effects, memos, batching, ownership, context |
| Phase 2: Server Rendering | ✅ Complete | HTML generation, SSR, hydration markers |
| Phase 3: Client Runtime | ✅ Complete | DOM bindings, hydration, reactive updates via Melange |
| Phase 4: Router | ✅ Complete | Route matching, navigation, data loaders, SSR support |
| Phase 5: Suspense | ✅ Complete | Async boundaries, error handling, unique IDs |

All core features are implemented and tested. **Ready for experimental use** - waiting for real-world validation.

## Documentation

- **[AGENTS.md](AGENTS.md)** - Development guidelines and project structure
- **[docs/A-01-architecture.md](docs/A-01-architecture.md)** - Full architecture document
- **[LIMITATIONS.md](LIMITATIONS.md)** - Known limitations and workarounds

## Contributing

Contributions welcome! See [AGENTS.md](AGENTS.md) for development guidelines.

## License

MIT

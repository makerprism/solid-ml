# solid-ml-server

An OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by [SolidJS](https://www.solidjs.com/).

**Status:** Experimental. Core features are complete, but the project is not production-hardened.

## Quick Start

```ocaml
open Solid_ml_server

let () =
  Runtime.run (fun () ->
    let dispose =
      Owner.create_root (fun () ->
        (* Create a signal (reactive value) *)
        let count, set_count = Signal.create 0 in

        (* Create a memo (derived value) *)
        let doubled = Memo.create (fun () ->
          Signal.get count * 2
        ) in

        (* Create an effect (side effect that re-runs when dependencies change) *)
        Effect.create (fun () ->
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

## Install (Dune package management)

Add one of the following to your project's `dune-project`:

```lisp
; Full stack + MLX (umbrella)
(depends
 (solid-ml (>= 0.1.0)))
```

```lisp
; Server-only
(depends
 (solid-ml-server (>= 0.1.0))
 (solid-ml-ssr (>= 0.1.0)))
```

```lisp
; Browser-only
(depends
 (solid-ml-browser (>= 0.1.0)))
```

```lisp
; Routing (SSR-aware)
(depends
 (solid-ml-router (>= 0.1.0)))
```

## Core API

### Runtime Context

Reactive primitives bind to the current owner/runtime if present. On the server,
solid-ml-server does not create an implicit runtime: you must call `Runtime.run` per
request (or use SSR helpers that do it for you) to keep state isolated.

```ocaml
(* Create isolated reactive context (recommended for SSR per-request) *)
Runtime.run (fun () ->
  let _count, _set_count = Signal.create 0 in
  ()
)
```

SSR helpers like `Solid_ml_ssr.Render.to_string` create and dispose a runtime internally.

### Signals

```ocaml
(* Create a signal with initial value (uses structural equality by default) *)
let count, set_count = Signal.create 0

(* Create with physical equality (for mutable values) *)
let buffer, set_buffer = Signal.create_physical (Bytes.create 100)

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
(* Effect re-runs when any signal it reads changes *)
Effect.create (fun () ->
  print_endline (string_of_int (Signal.get count))
)

(* Effect with cleanup *)
Effect.create_with_cleanup (fun () ->
  let subscription = subscribe_something () in
  fun () -> unsubscribe subscription
)

(* Read signal without tracking *)
let value = Effect.untrack (fun () -> Signal.get some_signal)
```

### Memos

```ocaml
(* Memo caches derived value, only recomputes when deps change *)
let doubled = Memo.create (fun () ->
  Signal.get count * 2
)

(* Read memo like a signal *)
let value = Memo.get doubled
```

### Batch

```ocaml
(* Batch multiple updates, effects run once at end *)
Batch.run (fun () ->
  Signal.set first_name "John";
  Signal.set last_name "Doe"
)
```

### Owner (Cleanup/Disposal)

```ocaml
(* Create a root that owns effects - dispose cleans everything up *)
let dispose = Owner.create_root (fun () ->
  Effect.create (fun () -> ...)
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

### Router (SSR-aware)

Router lives in `solid-ml-router` with SSR-aware components and loaders. See [examples/README.md](examples/README.md) for runnable demos.

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

## SolidJS Notes

Similarities:
- Signals/effects/memos with automatic dependency tracking
- Batch updates via `Batch.run`
- Suspense boundaries and error boundaries

Differences:
- Effects run synchronously by default (browser can opt into microtask deferral)
- Memos use structural equality by default (override with `~equals`)
- No concurrent rendering or transitions
- solid-ml-browser can create an implicit runtime; solid-ml-server requires `Runtime.run` per request. SolidJS SSR creates a new root per render/request.

Practical guidance:
- For server code, always create a runtime per request using `Runtime.run`, or use SSR helpers like `Solid_ml_ssr.Render.to_string`/`to_document` which create and dispose a runtime for you.
- Avoid creating signals at top level in server code; they now raise because no runtime is active.

## Docs

- [CHANGELOG.md](CHANGELOG.md) - Release notes and breaking changes
- [LIMITATIONS.md](LIMITATIONS.md) - Concise list of real constraints
- [docs/guide-mlx.md](docs/guide-mlx.md) - MLX syntax and template PPX setup
- [docs/guide-ssr-hydration.md](docs/guide-ssr-hydration.md) - SSR, hydration, and state transfer
- [examples/README.md](examples/README.md) - Example index and build commands

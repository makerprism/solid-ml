# solid-ml

An OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by [SolidJS](https://www.solidjs.com/).

> **Status:** Phase 2 (SSR) complete. Phase 3 (Client Runtime) not started.

## Features

- **Fine-grained reactivity** - Signals, effects, and memos with automatic dependency tracking
- **Server-side rendering** - Full HTML rendering for SEO and fast first paint
- **Thread-safe** - Domain-local storage enables safe parallel execution (OCaml 5)
- **MLX templates** - JSX-like syntax for OCaml via [mlx](https://github.com/ocaml-mlx/mlx)
- **Melange** - Compiles to optimized JavaScript (client runtime coming soon)
- **Type-safe** - Full OCaml type checking for your UI

## Quick Start

```ocaml
open Solid_ml

let () = Runtime.run (fun () ->
  let dispose = Owner.create_root (fun () ->
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
        (Signal.get doubled)
    );
    
    (* Update the signal - effect automatically re-runs *)
    set_count 1;  (* prints: Count: 1, Doubled: 2 *)
    set_count 2   (* prints: Count: 2, Doubled: 4 *)
  ) in
  dispose ()
)
```

## Core API

### Runtime

All reactive code must run within a `Runtime.run` context:

```ocaml
(* Create isolated reactive context *)
Runtime.run (fun () ->
  (* Reactive code here *)
)

(* For Dream/web servers - each request gets its own runtime *)
let handler _req =
  let html = Solid_ml_html.Render.to_string my_component in
  Dream.html html
```

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
let value = Signal.get doubled
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
    Runtime.run (fun () ->
      Render.to_string my_component
    )
  )
) |> Array.map Domain.join
```

**Important**: Signals should not be shared across runtimes or domains. Each runtime maintains its own reactive graph.

## Packages

| Package | Description | Status |
|---------|-------------|--------|
| `solid-ml` | Core reactive primitives (signals, effects, memos) | Ready |
| `solid-ml-html` | Server-side rendering to HTML strings | Ready |
| `solid-ml-dom` | Client-side rendering and hydration (Melange) | Planned |
| `solid-ml-router` | SSR-aware routing with data loaders | Planned |

## Building

```bash
# Build all packages
dune build

# Run tests
dune runtest

# Run counter example
dune exec examples/counter/counter.exe
```

## Requirements

- OCaml 5.0 or later (uses Domain-local storage)
- dune 3.0 or later

## Installation

> Coming soon to opam

## Documentation

See [docs/A-01-architecture.md](docs/A-01-architecture.md) for the full architecture document.

## License

MIT

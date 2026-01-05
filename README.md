# solid-ml

An OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by [SolidJS](https://www.solidjs.com/).

> **Status:** Early development. Not ready for production use.

## Features

- **Fine-grained reactivity** - Signals, effects, and memos with automatic dependency tracking
- **Server-side rendering** - Full HTML rendering for SEO and fast first paint
- **Client-side hydration** - Seamless transition to interactive SPA
- **MLX templates** - JSX-like syntax for OCaml via [mlx](https://github.com/ocaml-mlx/mlx)
- **Melange** - Compiles to optimized JavaScript
- **Type-safe** - Full OCaml type checking for your UI

## Example

```ocaml
open Solid_ml

let counter () =
  let count, set_count = Signal.create 0 in
  <div>
    <p>"Count: " (Signal.text count)</p>
    <button onclick=(fun _ -> Signal.update count succ)>
      "Increment"
    </button>
  </div>
```

## Packages

| Package | Description |
|---------|-------------|
| `solid-ml` | Core reactive primitives (signals, effects, memos) |
| `solid-ml-html` | Server-side rendering to HTML strings |
| `solid-ml-dom` | Client-side rendering and hydration (Melange) |
| `solid-ml-router` | SSR-aware routing with data loaders |

## Installation

> Coming soon to opam

## Documentation

See [docs/A-01-architecture.md](docs/A-01-architecture.md) for the full architecture document.

## License

MIT

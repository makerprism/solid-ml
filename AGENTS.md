# Agent Guidelines for solid-ml

## Project Overview

solid-ml is an OCaml framework for building reactive web applications with SSR, inspired by SolidJS.

**Repository:** github.com/makerprism/solid-ml  
**License:** MIT

## Documentation

- **Architecture:** `docs/A-01-architecture.md` - Full design document with API specs, SSR flow, and development phases

## Package Structure

| Package | Purpose | Status |
|---------|---------|--------|
| `solid-ml-internal` | Shared reactive core (functor-based, DO NOT use directly) | Complete |
| `solid-ml` | Server-side reactive framework (OCaml 5 with DLS) | Complete |
| `solid-ml-html` | Server-side rendering to HTML strings | Complete |
| `solid-ml-browser` | Browser-side reactive framework (Melange) | Complete |
| `solid-ml-router` | SSR-aware routing with data loaders | Not Started |

## Build Commands

```bash
# Build all packages (without Melange)
dune build

# Run tests
dune runtest

# Clean build artifacts
dune clean

# Build with esy (includes Melange for browser runtime)
esy install
esy build

# Run tests with esy
esy dune runtest
```

## Architecture

### Shared Core (`solid-ml-internal`)

The project uses a **functor-based architecture** to share reactive algorithms between server and browser:

```
solid-ml-internal/
├── types.ml           # Internal types (Obj.t for type erasure, phantom types for safety)
├── backend.ml         # Backend.S module type + Backend.Global implementation
├── reactive_functor.ml # Make(Backend) functor with all reactive algorithms
└── solid_ml_internal.ml
```

**Key insight:** The only platform difference is how the current runtime is stored:
- Server: Domain-local storage (thread-safe isolation per domain)
- Browser: Global ref (safe in single-threaded JS)

### Server (`solid-ml`)

```ocaml
(* Defines DLS backend and instantiates functor *)
module Backend_DLS : Internal.Backend.S = struct
  let runtime_key = Domain.DLS.new_key (fun () -> None)
  let get_runtime () = Domain.DLS.get runtime_key
  let set_runtime rt = Domain.DLS.set runtime_key rt
  let handle_error exn _ = raise exn
end

module R = Internal.Reactive_functor.Make(Backend_DLS)
```

### Browser (`solid-ml-browser`)

```ocaml
(* Defines global ref backend with console.error *)
module Backend_Browser : Internal.Backend.S = struct
  let current_runtime = ref None
  let get_runtime () = !current_runtime
  let set_runtime rt = current_runtime := rt
  let handle_error exn context =
    console_error ("solid-ml: Error in " ^ context ^ ": " ^ Printexc.to_string exn)
end

module R = Internal.Reactive_functor.Make(Backend_Browser)
```

### Type Safety

The internal types use `Obj.t` for type erasure (needed for heterogeneous collections), but expose type-safe APIs via phantom types:

```ocaml
(* Internal: untyped *)
type signal_state = { mutable value: Obj.t; ... }

(* Public: typed via phantom type parameter *)
type 'a signal = signal_state  (* 'a is phantom *)

let create_typed_signal (type a) ?equals (initial : a) : a signal =
  { value = Obj.repr initial; ... }

let read_typed_signal (type a) (s : a signal) : a =
  Obj.obj s.value
```

## Current Development Phase

**Phase 1: Reactive Core** (complete)

- [x] Signal.create, get, set, update, peek
- [x] Dependency tracking via execution context
- [x] Effect.create with auto-tracking
- [x] Effect.create_with_cleanup
- [x] Effect.untrack
- [x] Memo.create, create_with_equals (eager evaluation like SolidJS)
- [x] Batch.run with Signal integration
- [x] Owner.create_root, run_with_owner, on_cleanup, dispose
- [x] Context.create, provide, use
- [x] Comprehensive test suite (31 reactive + 23 HTML + 36 SolidJS compat = 90 tests)
- [x] Counter example in native OCaml
- [x] SolidJS compatibility test suite
- [x] Shared functor-based core for server and browser

**Phase 2: Server Rendering** (complete)

- [x] HTML element functions (div, p, input, etc.)
- [x] render_to_string function
- [x] Hydration markers for reactive text
- [x] Attribute escaping and boolean attributes
- [x] Comprehensive test suite (23 tests)

**Phase 3: Client Runtime** (complete)

- [x] Set up Melange build configuration (dune 3.16+, melange 0.1)
- [x] DOM API bindings (`lib/solid-ml-browser/dom.ml`)
- [x] HTML element functions mirroring solid-ml-html
- [x] Reactive DOM primitives
- [x] Browser reactive core using shared functor
- [x] Event handling system
- [x] Render function (client-side from scratch)
- [x] Hydrate function (basic implementation)
- [x] Browser counter example (`examples/browser_counter/`)
- [x] Builds successfully with esy
- [ ] Improve hydration to properly walk DOM tree

**Phase 4: Router** (not started)

See `docs/A-01-architecture.md` for Phase 4 tasks.

## Code Style

- Use OCaml standard library where possible
- Document public APIs with odoc comments
- Write tests for all new functionality
- Keep implementations simple - optimize later

## Key Files

| File | Purpose |
|------|---------|
| `lib/solid-ml-internal/types.ml` | Internal types with Obj.t + phantom type wrappers |
| `lib/solid-ml-internal/backend.ml` | Backend.S module type + Global implementation |
| `lib/solid-ml-internal/reactive_functor.ml` | Main functor with all reactive algorithms |
| `lib/solid-ml/reactive.ml` | Server instantiation with DLS backend |
| `lib/solid-ml/signal.ml` | Type-safe Signal API |
| `lib/solid-ml/effect.ml` | Effect API |
| `lib/solid-ml/memo.ml` | Memo API |
| `lib/solid-ml/batch.ml` | Batched updates |
| `lib/solid-ml/owner.ml` | Ownership and disposal tracking |
| `lib/solid-ml/context.ml` | Component context |
| `lib/solid-ml-html/html.ml` | HTML element functions for SSR |
| `lib/solid-ml-html/render.ml` | Render components to HTML strings |
| `lib/solid-ml-browser/reactive_core.ml` | Browser instantiation with global ref backend |
| `lib/solid-ml-browser/dom.ml` | Melange FFI bindings for browser DOM |
| `lib/solid-ml-browser/html.ml` | DOM element functions |
| `lib/solid-ml-browser/reactive.ml` | Reactive DOM bindings (text, attr, etc.) |
| `lib/solid-ml-browser/event.ml` | Event handling utilities |
| `lib/solid-ml-browser/render.ml` | Client-side render and hydrate functions |
| `test/test_reactive.ml` | Test suite for reactive primitives (31 tests) |
| `test/test_html.ml` | Test suite for HTML rendering (23 tests) |
| `test/test_solidjs_compat.ml` | SolidJS compatibility tests (36 tests) |
| `examples/counter/counter.ml` | Counter example demonstrating all features |

## Design Principles

1. **Fine-grained reactivity** - No virtual DOM, signals update only what depends on them
2. **Automatic tracking** - Reading a signal inside an effect/memo auto-subscribes
3. **Server/client isomorphism** - Same component code works on server (HTML) and client (DOM)
4. **Type safety** - Full OCaml type checking for UI code
5. **Shared core** - One implementation of reactive algorithms, platform-specific backends
6. **MLX syntax** - JSX-like templates via the mlx package

## Known Limitations

- Browser: Multiple independent apps on same page share global state
- Server: Each `Runtime.run` is fully isolated

**Important:** Signals should not be shared across runtimes or domains.

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
| `solid-ml-router` | SSR-aware routing with data loaders | Complete |

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
- [x] Hydrate function with text node adoption via hydration markers
- [x] Browser counter example (`examples/browser_counter/`)
- [x] Builds successfully with esy
- [x] Browser reactive tests (14 tests via Node.js)

**Phase 4: Router** (complete)

- [x] Route matching (static, params, wildcards)
- [x] Route pattern parsing
- [x] URL parsing (path, query, hash)
- [x] Query string parsing
- [x] Router context and state management
- [x] Router.navigate for programmatic navigation  
- [x] Link component for navigation
- [x] NavLink with active class support
- [x] Outlet component for rendering matched routes
- [x] RouterProvider for initializing router context
- [x] Comprehensive test suite (91 tests)
- [x] History API integration (browser)
- [x] Client-side navigation without reload (browser)
- [x] Scroll restoration
- [x] Loading/error states (Resource module)

**Test Summary:** 195 tests total (31 reactive + 23 HTML + 36 SolidJS compat + 91 router + 14 browser)

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
| `lib/solid-ml-browser/hydration.ml` | Hydration state and marker parsing |
| `lib/solid-ml-browser/event.ml` | Event handling utilities |
| `lib/solid-ml-browser/render.ml` | Client-side render and hydrate functions |
| `lib/solid-ml-router/route.ml` | Route pattern matching and params |
| `lib/solid-ml-router/router.ml` | Router state and navigation |
| `lib/solid-ml-router/components.ml` | Link, NavLink, Outlet components |
| `test/test_reactive.ml` | Test suite for reactive primitives (31 tests) |
| `test/test_html.ml` | Test suite for HTML rendering (23 tests) |
| `test/test_solidjs_compat.ml` | SolidJS compatibility tests (36 tests) |
| `test/test_router.ml` | Router tests (91 tests) |
| `test_browser/test_reactive.ml` | Browser reactive core tests (14 tests) |
| `examples/counter/counter.ml` | Counter example demonstrating reactive features |
| `examples/todo/todo.ml` | Todo list with SSR rendering |
| `examples/router/router.ml` | Router example with routes, params, NavLink |
| `examples/browser_counter/` | Browser counter + todo (Melange) |
| `examples/parallel/parallel.ml` | OCaml 5 domain parallelism demo |
| `examples/ssr_server/server.ml` | Dream server SSR demo (requires dream) |

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

## Differences from SolidJS

solid-ml aims to match SolidJS semantics closely. Here are the known differences:

### Implemented Features Matching SolidJS

| Feature | solid-ml | SolidJS | Notes |
|---------|----------|---------|-------|
| Signal equality | Physical (`!=`) | Reference (`===`) | Matches - both skip updates for same reference |
| Memo equality | Structural (`=`) | Reference (`===`) | solid-ml uses structural by default (customizable) |
| createSelector | `create_selector` | `createSelector` | Returns `(k -> bool)` with auto-cleanup |
| Effect.on | `Effect.on` | `on()` | Explicit deps, untracked body, `~defer` option |
| catchError | `Owner.catch_error` | `catchError` | Sync error handling (no setter reset) |
| Batch | `Batch.run` | `batch` | Groups updates, defers effects |
| Context | `Context.create/provide/use` | `createContext/useContext` | Owner-tree based lookup |

### Features NOT Implemented (Intentionally Omitted)

| Feature | Reason |
|---------|--------|
| `createResource` | Use `Resource` module in router for async data |
| `createDeferred` | No microtask scheduling in OCaml |
| `createReaction` | Use `Effect.on` for explicit tracking |
| `createRenderEffect` | Effects run synchronously already |
| Transitions API | Requires concurrent rendering not available in OCaml |
| Suspense | Would require effect-based async (use Resource instead) |
| `startTransition` | No concurrent mode |
| `useTransition` | No concurrent mode |
| `children` helper | Use direct children access |
| `lazy` | Use OCaml's native `lazy` |
| `createUniqueId` | Use a counter or UUID library |
| Event delegation | Uses inline handlers (simpler, same perf) |

### Semantic Differences

1. **Effect scheduling**: solid-ml effects run synchronously during `run_updates`. SolidJS sometimes defers to microtasks. This rarely matters in practice.

2. **Error boundaries**: `Owner.catch_error` catches synchronously thrown exceptions. SolidJS's `catchError` provides a setter to reset; solid-ml returns the fallback value directly since OCaml exceptions are sync.

3. **Context ID generation**: Not thread-safe (uses `ref`, not `Atomic`). Create contexts at module init time before spawning domains.

4. **No JSX compiler**: solid-ml requires manual DOM/HTML construction or use of MLX syntax. There's no Babel-like transform.

5. **Memo evaluation**: solid-ml memos are eager (computed immediately on creation). SolidJS memos are also eager but may defer in some cases.

### Browser-specific Notes

- `create_selector` auto-cleans up when the owning computation is disposed (via `Owner.on_cleanup`)
- No manual `unsubscribe` needed (unlike earlier versions)
- Multiple apps on same page share the global runtime ref

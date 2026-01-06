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
| `solid-ml` | Core reactive primitives (signals, effects, memos) | Complete |
| `solid-ml-html` | Server-side rendering to HTML strings | Complete |
| `solid-ml-dom` | Client-side rendering and hydration (Melange) | In Progress (code written, needs Melange) |
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

**Platform Strategy:**
- **Server (solid-ml, solid-ml-html):** OCaml 5 with Domain-local storage for thread safety
- **Browser (solid-ml-dom):** Single-threaded JavaScript, simpler implementation via Melange

**Two-Implementation Architecture:**

The project maintains **two separate reactive implementations**:

1. **Server (`lib/solid-ml/reactive.ml`):**
   - Uses Domain-local storage for thread-safe isolation
   - Each `Runtime.run` creates isolated state
   - Safe for concurrent requests in Dream/other servers
   - ~570 lines

2. **Browser (`lib/solid-ml-dom/reactive_core.ml`):**
   - Uses global state (safe because JavaScript is single-threaded)
   - Simpler implementation without Domain-local storage
   - Compiles to JavaScript via Melange
   - ~500 lines

**Why two implementations?**
- Domain-local storage doesn't exist in JavaScript
- Browser environment is inherently single-threaded
- Keeping them separate allows platform-specific optimizations
- Both follow the same SolidJS-inspired architecture

**API Compatibility:**
- Both implementations expose the same API (Signal, Effect, Memo, etc.)
- Tests only cover server implementation currently
- Behavior should be identical but browser tests are needed

**Known Limitations:**
- Browser: Multiple independent apps on same page share global state
- Server: Each `Runtime.run` is fully isolated

**Important:** Signals should not be shared across runtimes or domains. Each runtime maintains its own reactive graph.

**Phase 2: Server Rendering** (complete)

- [x] HTML element functions (div, p, input, etc.)
- [x] render_to_string function
- [x] Hydration markers for reactive text
- [x] Attribute escaping and boolean attributes
- [x] Comprehensive test suite (23 tests)

**Phase 3: Client Runtime** (complete - builds with esy)

- [x] Set up Melange build configuration (dune 3.16+, melange 0.1)
- [x] DOM API bindings (`lib/solid-ml-dom/dom.ml`)
- [x] HTML element functions mirroring solid-ml-html (`lib/solid-ml-dom/html.ml`)
- [x] Reactive DOM primitives (`lib/solid-ml-dom/reactive.ml`)
- [x] Browser-optimized reactive core (`lib/solid-ml-dom/reactive_core.ml`)
- [x] Event handling system (`lib/solid-ml-dom/event.ml`)
- [x] Render function (client-side from scratch)
- [x] Hydrate function (basic implementation)
- [x] Browser counter example (`examples/browser_counter/`)
- [x] Builds successfully with esy
- [ ] Improve hydration to properly walk DOM tree

**Note:** The solid-ml-dom package builds with esy (`esy install && esy build`).
It includes its own browser-optimized reactive core that doesn't need Domain-local storage.

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
| `lib/solid-ml/runtime.ml` | Thread-safe execution context for reactive state |
| `lib/solid-ml/signal.ml` | Reactive signals with dependency tracking |
| `lib/solid-ml/effect.ml` | Auto-tracking side effects |
| `lib/solid-ml/memo.ml` | Cached derived values |
| `lib/solid-ml/batch.ml` | Batched updates |
| `lib/solid-ml/owner.ml` | Ownership and disposal tracking |
| `lib/solid-ml/context.ml` | Component context (stored on owner tree) |
| `lib/solid-ml-html/html.ml` | HTML element functions for SSR |
| `lib/solid-ml-html/render.ml` | Render components to HTML strings |
| `lib/solid-ml-dom/dom.ml` | Melange FFI bindings for browser DOM |
| `lib/solid-ml-dom/html.ml` | DOM element functions (mirrors solid-ml-html) |
| `lib/solid-ml-dom/reactive.ml` | Reactive DOM bindings (text, attr, etc.) |
| `lib/solid-ml-dom/reactive_core.ml` | Browser-optimized reactive core |
| `lib/solid-ml-dom/event.ml` | Event handling utilities |
| `lib/solid-ml-dom/render.ml` | Client-side render and hydrate functions |
| `test/test_reactive.ml` | Test suite for reactive primitives (31 tests) |
| `test/test_html.ml` | Test suite for HTML rendering (23 tests) |
| `test/test_solidjs_compat.ml` | SolidJS compatibility tests (36 tests) |
| `examples/counter/counter.ml` | Counter example demonstrating all features |

## Design Principles

1. **Fine-grained reactivity** - No virtual DOM, signals update only what depends on them
2. **Automatic tracking** - Reading a signal inside an effect/memo auto-subscribes
3. **Server/client isomorphism** - Same component code works on server (HTML) and client (DOM)
4. **Type safety** - Full OCaml type checking for UI code
5. **MLX syntax** - JSX-like templates via the mlx package

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
| `solid-ml-dom` | Client-side rendering and hydration (Melange) | Not Started |
| `solid-ml-router` | SSR-aware routing with data loaders | Not Started |

## Build Commands

```bash
# Build all packages
dune build

# Run tests
dune runtest

# Clean build artifacts
dune clean
```

## Current Development Phase

**Phase 1: Reactive Core** (complete)

- [x] Signal.create, get, set, update, peek
- [x] Dependency tracking via execution context
- [x] Effect.create with auto-tracking
- [x] Effect.create_with_cleanup
- [x] Effect.untrack
- [x] Memo.create, create_with_equals
- [x] Batch.run with Signal integration
- [x] Owner.create_root, run_with_owner, on_cleanup, dispose
- [x] Context.create, provide, use
- [x] Comprehensive test suite (28 tests)
- [x] Counter example in native OCaml

**Thread Safety:**
- All reactive state is stored in `Runtime.t`, not global variables
- Each `Runtime.run` or `Render.to_string` creates isolated state
- Uses Domain-local storage (OCaml 5) for safe parallel execution across domains
- Safe for concurrent requests in Dream or other servers

**Important:** Signals should not be shared across runtimes or domains. Each runtime maintains its own reactive graph.

**Phase 2: Server Rendering** (complete)

- [x] HTML element functions (div, p, input, etc.)
- [x] render_to_string function
- [x] Hydration markers for reactive text
- [x] Attribute escaping and boolean attributes
- [x] Comprehensive test suite (23 tests)

**Phase 3: Client Runtime** (next)

See `docs/A-01-architecture.md` for Phase 3 tasks.

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
| `test/test_reactive.ml` | Test suite for reactive primitives (31 tests) |
| `test/test_html.ml` | Test suite for HTML rendering (23 tests) |
| `examples/counter/counter.ml` | Counter example demonstrating all features |

## Design Principles

1. **Fine-grained reactivity** - No virtual DOM, signals update only what depends on them
2. **Automatic tracking** - Reading a signal inside an effect/memo auto-subscribes
3. **Server/client isomorphism** - Same component code works on server (HTML) and client (DOM)
4. **Type safety** - Full OCaml type checking for UI code
5. **MLX syntax** - JSX-like templates via the mlx package

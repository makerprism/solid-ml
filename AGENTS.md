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
| `solid-ml` | Core reactive primitives (signals, effects, memos) | In Progress |
| `solid-ml-html` | Server-side rendering to HTML strings | Not Started |
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

**Phase 1: Reactive Core** (in progress)

Completed:
- [x] Signal.create, get, set, update, peek
- [x] Dependency tracking via execution context
- [x] Effect.create with auto-tracking
- [x] Effect.create_with_cleanup
- [x] Effect.untrack
- [x] Memo.create
- [x] Batch.run (basic implementation)
- [x] Basic test suite

Remaining:
- [ ] Ownership tracking for cleanup/disposal
- [ ] Context (createContext equivalent)
- [ ] More comprehensive tests
- [ ] Example: counter in native OCaml

## Code Style

- Use OCaml standard library where possible
- Document public APIs with odoc comments
- Write tests for all new functionality
- Keep implementations simple - optimize later

## Key Files

| File | Purpose |
|------|---------|
| `lib/solid-ml/signal.ml` | Reactive signals with dependency tracking |
| `lib/solid-ml/effect.ml` | Auto-tracking side effects |
| `lib/solid-ml/memo.ml` | Cached derived values |
| `lib/solid-ml/batch.ml` | Batched updates |
| `test/test_reactive.ml` | Test suite for reactive primitives |

## Design Principles

1. **Fine-grained reactivity** - No virtual DOM, signals update only what depends on them
2. **Automatic tracking** - Reading a signal inside an effect/memo auto-subscribes
3. **Server/client isomorphism** - Same component code works on server (HTML) and client (DOM)
4. **Type safety** - Full OCaml type checking for UI code
5. **MLX syntax** - JSX-like templates via the mlx package

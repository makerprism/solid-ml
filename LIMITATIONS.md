# solid-ml Limitations

This document describes the current limitations, constraints, and known issues with solid-ml. Understanding these limitations is essential for using the framework effectively.

## Current Status

All 5 development phases are complete. solid-ml has 217 tests passing.

**Maturity:** Experimental (started January 5, 2026). Not battle-tested in production yet. Expect rapid iteration and potential breaking changes.

| Feature | Status | Notes |
|---------|--------|-------|
| Reactive primitives | ✅ Complete | Signals, effects, memos, batch, owner, context |
| Server-side rendering | ✅ Complete | HTML generation with hydration markers |
| Client-side rendering | ✅ Complete | Full DOM bindings via Melange |
| Hydration | ✅ Complete | Text nodes via markers, elements via cursor-based adoption |
| Router | ✅ Complete | SSR-aware routing with data loaders |
| Suspense/ErrorBoundary | ✅ Complete | Async boundaries and error handling |

---

## Critical Limitations

### 1. Browser Package Requires Melange

**Issue:** The `solid-ml-browser` package compiles to JavaScript via Melange and cannot be built with standard OCaml toolchains.

**Impact:** 
- Server-side packages (`solid-ml`, `solid-ml-ssr`, `solid-ml-router`) work with standard OCaml
- Browser package requires Melange 3.0+ (installed via dune package management)

**Solution:** Melange is automatically installed via dune package management:
```bash
dune build lib/solid-ml-browser
```

For browser examples:
```bash
make browser-examples
make serve
```

**Example browser code:**
```ocaml
open Solid_ml_browser
open Reactive

let counter () =
  let count, set_count = Signal.create 0 in
  Html.div [] [
    Html.p [] [Reactive.text count];
    Html.button 
      [Html.on_click (fun _ -> Signal.update count succ)] 
      [Html.text "+"]
  ]

let () =
  match Dom.get_element_by_id (Dom.document ()) "app" with
  | Some root -> ignore (Render.render root counter)
  | None -> Dom.error "No #app element found"
```

---

### 2. Signals Cannot Be Shared Across Runtimes/Domains

**Issue:** Each `Runtime.run` or `Render.to_string` call creates an isolated reactive context. Signals created in one runtime cannot be accessed from another.

**Impact:**
- Cannot create "global" signals that persist across requests
- Cannot share reactive state between parallel domain executions

**Why:** This is by design for thread safety. Each domain has its own Domain-local storage, ensuring no data races.

**Incorrect usage:**
```ocaml
(* DON'T DO THIS - signal from one runtime used in another *)
let global_count, set_global = 
  Runtime.run (fun () -> Signal.create 0)  (* Signal created here *)

let handler () =
  Runtime.run (fun () ->
    Signal.get global_count  (* ERROR: wrong runtime context! *)
  )
```

**Correct usage:**
```ocaml
(* Each request creates its own signals *)
let handler () =
  Runtime.run (fun () ->
    let count, set_count = Signal.create 0 in
    (* Use count within this runtime only *)
    ...
  )
```

**Note:** If you create signals outside `Runtime.run`, they live in an implicit
per-domain runtime and will persist across requests. This is convenient for
clients but unsafe for server request isolation.

---

### 3. No Async/Lwt Support in Reactive Primitives

**Issue:** Effects and memos are synchronous. There's no built-in support for async operations like data fetching within reactive code.

**Impact:**
- Cannot use `Lwt.t` or `Async.t` inside effects
- Data loading must happen before entering the reactive context or via Router Resources

**Solutions:**

**Server-side - Fetch before rendering:**
```ocaml
let handler req =
  let%lwt data = Database.fetch_todos () in  (* Async happens here *)
  let html = Render.to_string (fun () -> 
    todo_page ~todos:data ()  (* Sync rendering with data *)
  ) in
  Dream.html html
```

**Client-side - Use Router Resources with Suspense:**
```ocaml
open Solid_ml_router

let user_resource, _actions = Resource.create_resource (fun () ->
  fetch_user_data ()
) 

let user_page () =
  Suspense.boundary
    ~fallback:(fun () -> [Html.div [] [Html.text "Loading..."]])
    ~children:(fun () ->
      let user =
        Resource.read_suspense
          ~default:None
          ~error_to_string:(fun err -> err)
          user_resource
      in
      [Html.div [] [Html.text user.name]]
    )
```

---

### 4. Memory Leaks if Owner.create_root Not Disposed

**Issue:** Effects and cleanup functions are stored in owner nodes. If you create a root and never dispose it, these resources leak.

**Impact:** Long-running applications may accumulate memory if roots aren't cleaned up.

**Correct usage:**
```ocaml
let dispose = Owner.create_root (fun () ->
  Effect.create (fun () -> ...)
) in
(* Later, when done: *)
dispose ()
```

**Note:** `Render.to_string` handles this automatically - it creates and disposes a root internally.

---

### 5. No JSX/Template Compiler

**Issue:** SolidJS ships with `babel-plugin-jsx-dom-expressions`, which compiles JSX into DOM instructions, hoists static markup, and inserts fine-grained subscriptions automatically. solid-ml currently relies on handwritten OCaml (or MLX) without a compilation step.

**Impact:** Component code is more verbose, and static subtrees are re-created at runtime instead of being cloned. Initialization work is higher than SolidJS because we cannot pre-analyse templates.

**Workaround:** Factor large static subtrees into helper functions or values so they are only constructed once. A future PPX/JSX-style compiler is needed for feature parity.

---

### 6. No Store-style Nested Reactivity

**Issue:** SolidJS `createStore` tracks nested updates via proxies. solid-ml exposes signals only at the top level.

**Impact:** Updating a field of a record or an element of a list requires replacing the entire signal value, which retriggers every subscriber even if only a small fragment changed.

**Workaround:** Normalize state into multiple signals (one per field/item) or expose setter helpers that update disjoint signals. Exploring a store-like API is future work.

---

### 7. Synchronous Effect Scheduling

**Issue:** SolidJS batches updates and flushes effects on the microtask queue. solid-ml runs effects synchronously as dependencies change.

**Impact:** Without manual batching, a burst of `Signal.set` calls can re-run downstream computations repeatedly, and intermediate states may be visible during the update.

**Workaround:** Wrap related updates in `Batch.run` and design computations to tolerate synchronous execution. Implementing a microtask-style scheduler would close this gap.

---

### 8. No Streaming SSR or Event Replay

**Issue:** SolidJS supports `renderToStream` and ships a hydration script that queues DOM events until hydration completes. solid-ml currently offers `Render.to_string` (buffered output) and drops events that fire before the browser runtime mounts.

**Impact:** Large pages cannot start rendering progressively, and early user interactions are lost.

**Workaround:** Keep initial HTML lightweight and defer interactive controls until the client bundle boots. Streaming plus event replay should be added for full parity.

---

### 9. Error Boundaries Require Manual Setup

**Issue:** Error boundaries are available but must be explicitly wrapped around components.

**Impact:** Exceptions in components will propagate unless caught by an ErrorBoundary.

**Solution:** Use ErrorBoundary.make:
```ocaml
open Solid_ml

let safe_component () =
  ErrorBoundary.make
    ~fallback:(fun error reset ->
      [Html.div [] [
        Html.text ("Error: " ^ error);
        Html.button [Html.on_click (fun _ -> reset ())] [Html.text "Retry"]
      ]]
    )
    ~children:(fun () ->
      (* Component code that might throw *)
      risky_component ()
    )
```

**Server-side fallback:**
```ocaml
let safe_render component =
  try Render.to_string component
  with exn ->
    Printf.sprintf "<div class='error'>Error: %s</div>" 
      (Printexc.to_string exn)
```

---

### 10. Hydration and Code Sharing

**Status:** Hydration now supports both text nodes AND elements via cursor-based adoption.

**How it works:**
- **Text nodes:** Adopted via hydration markers (`<!--hk:N-->text<!--/hk-->`)
- **Elements:** Adopted by matching tag name and position (cursor-based)
- **Event handlers:** Attached to adopted elements during hydration

**SSR vs Browser APIs:**
- **Unified API:** Both SSR and Browser use `Html.reactive_text` (SSR renders markers, Browser adopts them)
- **Event handlers:** Unified API (SSR ignores handlers, Browser attaches them)

**Code sharing approach:** Use the functor-based `Component.COMPONENT_ENV` module type:
```ocaml
(* shared/counter.ml *)
module Counter (Env : Solid_ml.Component.COMPONENT_ENV) = struct
  open Env
  let render ~initial () =
    let count, _set_count = Signal.create initial in
    Html.div ~children:[Html.reactive_text count] ()
end
```

**Limitations:**
- Component structure must match exactly between server and client
- No validation for mismatched structures (fails silently)

---

### 11. Hydration Markers May Cause Layout Issues


**Issue:** Reactive text nodes are wrapped in HTML comments: `<!--hk:0-->text<!--/hk-->`

**Impact:** In some CSS contexts (e.g., flexbox with `gap`), HTML comments are treated as nodes and may affect layout.

**Workaround:** Be aware of this when styling, or wrap reactive text in a `<span>`.

---

## API Limitations

### HTML Elements

**Event handlers:**
- Available in `solid-ml-browser` via `Html.on_*` attributes
- Not available in `solid-ml-ssr` (server-side only generates HTML strings)

**Custom attributes:**
- `data-*` attributes require manual construction via generic attribute functions
- Some ARIA attributes may need manual construction

**Missing elements:**
- `<canvas>` (available but limited API)
- `<dialog>`, `<details>`, `<summary>`
- `<template>`, `<slot>` (web components)

### Control Flow

solid-ml intentionally relies on OCaml's native `if`, `match`, and higher-order functions instead of providing `<Show>`, `<For>`, or `<Switch>` helpers. Those primitives primarily benefit template-driven syntaxes (e.g., JSX); with plain OCaml syntax the language already offers precise control flow.

### Signals

**Functional updates use Signal.update:**
```ocaml
(* SolidJS *)
setCount(c => c + 1);

(* solid-ml *)
Signal.update count (fun c -> c + 1)
```

### SVG

- Server helpers add `xmlns="http://www.w3.org/2000/svg"` automatically to the root `<svg>`.
  Pass `~xmlns:false` to `Html.Svg.svg` (or `Html.svg`) when rendering nested SVG elements
  to avoid duplicate namespace attributes.

**Explicit dependency tracking uses Effect.on:**
```ocaml
(* SolidJS *)
on(count, (value) => console.log(value));

(* solid-ml *)
Effect.on [count] (fun () ->
  print_endline (string_of_int (Signal.get count))
) ()
```

These are design differences, not missing features. See [SolidJS compatibility in AGENTS.md](AGENTS.md#differences-from-solidjs) for details.

### Context

**No context in render functions:**
- Context only works within `Owner.create_root` scope
- `Render.to_string` creates its own root, so context must be set up inside the component

---

## Performance Considerations

### 1. No Fine-Grained DOM Updates (Server-Side)

On the server, solid-ml generates complete HTML strings. There's no incremental rendering or streaming (yet).

### 1.1 List Reconciliation Semantics

solid-ml template lists map to SolidJS list helpers:

- `Tpl.each` and `Tpl.eachi` reconcile by index (value-based render, nodes may be replaced on change).
- `Tpl.each_indexed` reconciles by index with accessors (SolidJS `<Index>`).
- `Tpl.each_keyed` reconciles by key (SolidJS `<For>`). Ownership follows key.

If you need stable per-item identity across inserts/removals, use `Tpl.each_keyed` with a durable key.

### 1.2 Template ErrorBoundary on SSR

Template-level `Tpl.error_boundary` uses `ErrorBoundary.Unsafe.make` on SSR because the
template environment does not create an owner scope. The behavior matches normal
error boundaries, but the implementation bypasses ownership tracking.

### 2. Structural Equality by Default

Signals use structural equality (`=`) by default, which is safe but may be slow for large data structures.

**Optimization:** Use `Signal.create_physical` for large mutable values:
```ocaml
(* For large arrays/records where identity matters *)
let data, set_data = Signal.create_physical large_array
```

### 3. No Automatic Batching

Unlike some frameworks, solid-ml doesn't automatically batch updates within event handlers (since there are no event handlers yet). Use `Batch.run` explicitly:

```ocaml
Batch.run (fun () ->
  set_first_name "John";
  set_last_name "Doe";
  (* Effects run once after both updates *)
)
```

---

## Platform Requirements

- **OCaml 5.0+** - Required for Domain-local storage
- **Native or Melange** - Not compatible with js_of_ocaml (different JS compilation approach)
- **dune 3.0+** - Build system requirement

---

## Future Enhancements

The following features are planned or could be added based on community feedback:

| Enhancement | Description | Priority |
|-------------|-------------|----------|
| Unified Html interface | Single module signature for SSR and browser | ✅ Done |
| Full element adoption | Hydrate elements, not just text nodes | ✅ Done |
| Shared component abstraction | Same `.ml` file compiles for both targets | ✅ Done (via functor) |
| Portal support | Render outside component hierarchy | ✅ Done |
| Template compiler | JSX/MLX compilation for static hoisting & diffable templates | High |
| Store API | Fine-grained nested updates (createStore equivalent) | Medium |
| Microtask scheduler | Deferred effect flushing / automatic batching | Medium |
| Streaming SSR & event replay | Stream HTML and buffer pre-hydration events | High |
| Async effects | Direct Promise/Lwt support in effects | Low |
| Event delegation | Global event handling (currently inline) | Low |
| Custom directives | Extensible attribute system | Low |

---

## Reporting Issues

Found a bug or limitation not documented here? Please open an issue at:
https://github.com/makerprism/solid-ml/issues

Include:
1. solid-ml version
2. OCaml version
3. Minimal reproduction code
4. Expected vs actual behavior

# solid-ml Limitations

This document describes the current limitations, constraints, and known issues with solid-ml. Understanding these limitations is essential for using the framework effectively.

## Current Status

All 5 development phases are complete. solid-ml has 208 tests passing.

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
- Browser package requires Melange 3.0+ installed via `esy` or opam

**Solution:** Use esy for browser builds:
```bash
esy install
esy build
```

Or install Melange via opam:
```bash
opam install melange
dune build
```

**Example browser code:**
```ocaml
open Solid_ml_browser

let counter () =
  Runtime.run (fun () ->
    let count, set_count = Signal.create 0 in
    let root = Html.div [] [
      Html.p [] [Reactive.text (fun () -> string_of_int (Signal.get count))];
      Html.button 
        [Html.on_click (fun _ -> Signal.update count succ)] 
        [Html.text "+"]
    ] in
    Render.hydrate root (Dom.get_element_by_id "app")
  )
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

let user_resource = Resource.create (fun id ->
  fetch_user_data id  (* Returns promise/data *)
)

let user_page () =
  Suspense.boundary
    ~fallback:(fun () -> [Html.div [] [Html.text "Loading..."]])
    ~children:(fun () ->
      let user = Resource.read_suspense user_resource ~default:None in
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

### 5. No Built-in Conditional Rendering Helpers

**Issue:** There are no `Show`, `Switch`, `For`, or `Index` components like in SolidJS.

**Impact:** Conditional and list rendering requires manual pattern matching and list functions.

**Current approach:**
```ocaml
(* Conditional rendering - use if/match *)
let content = 
  if Signal.get is_loading then
    Html.p [] [Html.text "Loading..."]
  else
    Html.div [] [actual_content ()]

(* List rendering - use List.map *)
let items = List.map (fun item ->
  Html.li [] [Html.text item.name]
) (Signal.get items_signal)

(* Switch-like rendering *)
match Signal.get state with
| Loading -> Html.div [] [Html.text "Loading..."]
| Error e -> Html.div [] [Html.text ("Error: " ^ e)]
| Success data -> render_data data
```

**Note:** This is idiomatic OCaml and works well. Control flow helpers may be added in future versions for convenience.

---

### 6. Error Boundaries Require Manual Setup

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

### 7. Hydration and Code Sharing

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

### 8. Hydration Markers May Cause Layout Issues


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
| Streaming SSR | `render_to_stream` for chunked responses | Medium |
| Control flow helpers | `Show`, `For`, `Switch` components | Low |
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

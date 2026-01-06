# solid-ml Limitations

This document describes the current limitations, constraints, and known issues with solid-ml. Understanding these limitations is essential for using the framework effectively.

## Current Status

solid-ml is in early development. Phases 1-2 are complete, Phase 3 code is written but needs Melange to test.

| Feature | Status | Notes |
|---------|--------|-------|
| Reactive primitives | Complete | Signals, effects, memos, batch, owner, context |
| Server-side rendering | Complete | HTML generation with hydration markers |
| Client-side rendering | Code Written | Requires Melange (`opam install melange`) |
| Hydration | Basic | Marker parsing done, DOM walking needs improvement |
| Router | Not Started | Phase 4: SSR-aware routing |

---

## Critical Limitations

### 1. Client-Side Requires Melange

**Issue:** The solid-ml-dom package provides client-side rendering but requires Melange to be installed.

**Impact:** 
- Without Melange, only server-side rendering works
- The solid-ml-dom package is marked as `(optional)` and won't build without Melange

**Solution:** Install Melange to enable client-side:
```bash
opam install melange
dune build @melange
```

**Example of client-side code (requires Melange):**
```ocaml
open Solid_ml_dom

let counter () =
  let count, set_count = Signal.create 0 in
  Html.(
    div ~children:[
      p ~children:[Reactive.text count] ();
      (let btn = button ~children:[text "+"] () in
       match Html.get_element btn with
       | Some el -> Event.on_click el (fun _ -> Signal.update count succ)
       | None -> ();
       btn)
    ] ()
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

**Issue:** Effects and memos are synchronous. There's no built-in support for async operations like data fetching.

**Impact:**
- Cannot use `Lwt.t` or `Async.t` inside effects
- Data loading must happen before entering the reactive context

**Workaround:** Fetch data before rendering, pass it as props:
```ocaml
let handler req =
  let%lwt data = Database.fetch_todos () in  (* Async happens here *)
  let html = Render.to_string (fun () -> 
    todo_page ~todos:data ()  (* Sync rendering with data *)
  ) in
  Dream.html html
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

### 5. No Conditional Rendering Helpers

**Issue:** There are no `Show`, `Switch`, `For`, or `Index` components like in SolidJS.

**Impact:** Conditional and list rendering requires manual pattern matching.

**Current approach:**
```ocaml
(* Conditional rendering *)
let content = 
  if Signal.get is_loading then
    Html.p ~children:[Html.text "Loading..."] ()
  else
    Html.div ~children:[...] ()

(* List rendering *)
let items = List.map (fun item ->
  Html.li ~children:[Html.text item.name] ()
) (Signal.get items_signal)
```

---

### 6. No Error Boundaries

**Issue:** There's no way to catch and handle errors within the component tree.

**Impact:** An exception in any component will crash the entire render.

**Workaround:** Wrap rendering in try-catch:
```ocaml
let safe_render component =
  try Render.to_string component
  with exn ->
    Printf.sprintf "<div class='error'>Error: %s</div>" 
      (Printexc.to_string exn)
```

---

### 7. Hydration Markers May Cause Layout Issues

**Issue:** Reactive text nodes are wrapped in HTML comments: `<!--hk:0-->text<!--/hk-->`

**Impact:** In some CSS contexts (e.g., flexbox with `gap`), HTML comments are treated as nodes and may affect layout.

**Workaround:** Be aware of this when styling, or wrap reactive text in a `<span>`.

---

## API Limitations

### HTML Elements

**Missing attributes:**
- Event handlers (`onclick`, `onchange`, etc.) - no client-side yet
- `data-*` attributes require manual construction
- ARIA attributes are limited
- SVG elements not implemented

**Missing elements:**
- `<canvas>`, `<svg>`, `<path>`, etc.
- `<dialog>`, `<details>`, `<summary>`
- `<template>`, `<slot>`

### Signals

**No derived setters:**
```ocaml
(* SolidJS has this, solid-ml doesn't *)
let [count, setCount] = createSignal(0);
setCount(c => c + 1);  (* Functional update *)

(* solid-ml requires Signal.update *)
Signal.update count (fun c -> c + 1)
```

**No `on` helper for explicit subscriptions:**
```ocaml
(* SolidJS *)
on(count, (value) => console.log(value));

(* solid-ml - use Effect.create instead *)
Effect.create (fun () ->
  print_endline (string_of_int (Signal.get count))
)
```

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

## Roadmap to Address Limitations

| Limitation | Planned Resolution | Phase |
|------------|-------------------|-------|
| No client-side | Melange DOM bindings | Phase 3 |
| No hydration | `hydrate` function | Phase 3 |
| No event handlers | Event delegation system | Phase 3 |
| No routing | solid-ml-router package | Phase 4 |
| No streaming SSR | `render_to_stream` | Future |
| No Suspense/async | Resource primitive | Future |

---

## Reporting Issues

Found a bug or limitation not documented here? Please open an issue at:
https://github.com/makerprism/solid-ml/issues

Include:
1. solid-ml version
2. OCaml version
3. Minimal reproduction code
4. Expected vs actual behavior

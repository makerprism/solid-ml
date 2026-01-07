# A-01: solid-ml Architecture

**Status:** Draft  
**Date:** January 2026  
**Repository:** github.com/makerprism/solid-ml  
**License:** MIT

---

## Context

solid-ml is an OCaml framework for building reactive web applications with server-side rendering (SSR), inspired by SolidJS. It provides:

- Fine-grained reactivity (signals, effects, memos)
- Server-side rendering to HTML strings
- Client-side hydration via Melange
- SSR-aware routing with data loaders

### Why Build This?

No existing OCaml solution provides SolidJS-style fine-grained reactivity with SSR:

| Framework | Issue |
|-----------|-------|
| Eliom | Heavy, opinionated, requires Ocsigen server |
| Bonsai | No SSR support (client-only) |
| js_of_ocaml + manual | No reactive primitives, large bundles |
| React/ReactiveData | FRP-style, not fine-grained, no SSR |

### Goals

1. **SEO-friendly** - Server renders full HTML for crawlers
2. **Interactive** - Client hydrates and becomes a reactive SPA
3. **Type-safe** - Full OCaml type checking for UI code
4. **Performant** - Fine-grained updates (no virtual DOM diffing)
5. **Familiar** - API inspired by SolidJS, syntax via MLX

---

## Decision

### Technology Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Template syntax | MLX | JSX-like syntax for OCaml, proven with Melange |
| JS compiler | Melange | Smaller bundles than js_of_ocaml, better JS interop |
| Server | Agnostic | `render_to_string` works with Dream, Eliom, etc. |
| Reactivity | Custom | SolidJS-inspired fine-grained signals |

### Package Structure

```
solid-ml/
├── lib/
│   ├── solid-ml/             # Core reactive primitives (shared code)
│   │   ├── signal.ml         # Signals with dependency tracking
│   │   ├── effect.ml         # Side effects with auto-tracking
│   │   ├── memo.ml           # Cached derived values
│   │   ├── batch.ml          # Batched updates
│   │   ├── context.ml        # Component context
│   │   └── owner.ml          # Ownership/disposal tracking
│   │
│   ├── solid-ml-dom/         # Client-side rendering (Melange)
│   │   ├── render.ml         # Render MLX to DOM
│   │   ├── hydrate.ml        # Hydrate server-rendered HTML
│   │   ├── event.ml          # Event delegation
│   │   └── bindings/
│   │       └── dom.ml        # DOM API bindings
│   │
│   ├── solid-ml-ssr/        # Server-side rendering (Native OCaml)
│   │   ├── render.ml         # Render MLX to HTML string
│   │   ├── stream.ml         # Streaming render (future)
│   │   └── hydration_script.ml  # Generate hydration data
│   │
│   └── solid-ml-router/      # Routing with SSR support
│       ├── router.ml         # Route matching
│       ├── link.ml           # Client-side navigation
│       └── loader.ml         # Route data loaders
│
└── examples/
    ├── counter/              # Basic example
    └── venues-search/        # KaraokeCrowd migration example
```

---

## Core API Design

### Signals

Signals are reactive values that track dependencies automatically.

```ocaml
(* solid-ml/signal.mli *)

(** A reactive value that tracks dependencies *)
type 'a t

(** Create a signal with initial value. Returns (signal, setter) *)
val create : 'a -> 'a t * ('a -> unit)

(** Read current value (tracks dependency in reactive context) *)
val get : 'a t -> 'a

(** Read without tracking dependency *)
val peek : 'a t -> 'a

(** Update signal value *)
val set : 'a t -> 'a -> unit

(** Update based on previous value *)
val update : 'a t -> ('a -> 'a) -> unit
```

**Example:**
```ocaml
let count, set_count = Signal.create 0

(* Reading tracks dependency *)
let current = Signal.get count  (* 0 *)

(* Writing notifies dependents *)
Signal.set count 1
Signal.update count (fun n -> n + 1)  (* now 2 *)
```

### Effects

Effects are side effects that re-run when their dependencies change.

```ocaml
(* solid-ml/effect.mli *)

(** Create an effect that re-runs when dependencies change *)
val create : (unit -> unit) -> unit

(** Create an effect with cleanup function *)
val create_with_cleanup : (unit -> (unit -> unit)) -> unit

(** Run code without tracking dependencies *)
val untrack : (unit -> 'a) -> 'a
```

**Example:**
```ocaml
let count, set_count = Signal.create 0

(* This effect re-runs whenever count changes *)
Effect.create (fun () ->
  print_endline ("Count is: " ^ string_of_int (Signal.get count))
)

set_count 1  (* prints "Count is: 1" *)
set_count 2  (* prints "Count is: 2" *)
```

### Memos

Memos are cached derived values that only recompute when dependencies change.

```ocaml
(* solid-ml/memo.mli *)

(** Create a cached derived value *)
val create : (unit -> 'a) -> 'a Signal.t

(** Create with custom equality function *)
val create_with_equals : eq:('a -> 'a -> bool) -> (unit -> 'a) -> 'a Signal.t
```

**Example:**
```ocaml
let count, set_count = Signal.create 0

(* Only recomputes when count changes *)
let doubled = Memo.create (fun () -> Signal.get count * 2)

Signal.get doubled  (* 0 *)
set_count 5
Signal.get doubled  (* 10 *)
```

### Context

Context provides a way to pass values down the component tree without prop drilling.

```ocaml
(* solid-ml/context.mli *)

type 'a t

(** Create a new context with default value *)
val create : 'a -> 'a t

(** Provide a value to descendants *)
val provide : 'a t -> 'a -> (unit -> 'b) -> 'b

(** Use the context value *)
val use : 'a t -> 'a
```

---

## MLX Integration

### How MLX Works

MLX transforms JSX syntax to OCaml function calls:

```ocaml
(* MLX input *)
<div class_="container">
  <p>"Hello"</p>
</div>

(* Transforms to *)
div () ~class_:"container" ~children:[
  p () ~children:["Hello"] [@JSX]
] [@JSX]
```

### Runtime Libraries

solid-ml provides two runtime libraries that implement these element functions:

**solid-ml-ssr (Server):**
```ocaml
let div ?class_ ?(children=[]) () =
  let attrs = match class_ with 
    | Some c -> Printf.sprintf " class=\"%s\"" c 
    | None -> "" 
  in
  Printf.sprintf "<div%s>%s</div>" attrs (String.concat "" children)
```

**solid-ml-dom (Client):**
```ocaml
let div ?class_ ?(children=[]) () =
  let el = Dom.create_element "div" in
  Option.iter (Dom.set_class el) class_;
  List.iter (Dom.append_child el) children;
  el
```

### Reactive Elements

For reactive content, special helpers bridge signals to the DOM:

```ocaml
(* Reactive text that updates automatically *)
let counter () =
  let count, set_count = Signal.create 0 in
  <div>
    <p>(Signal.text count)</p>
    <button onclick=(fun _ -> Signal.update count succ)>
      "Increment"
    </button>
  </div>
```

`Signal.text` creates a text node that subscribes to the signal:

```ocaml
(* solid-ml-dom/signal_dom.ml *)
let text signal =
  let node = Dom.create_text_node (string_of_int (Signal.get signal)) in
  Effect.create (fun () ->
    Dom.set_text_content node (string_of_int (Signal.get signal))
  );
  node
```

---

## SSR + Hydration Flow

### Overview

```
1. Browser Request    GET /venues
        ↓
2. Route Loader       Fetch venues from API/database
        ↓
3. Server Render      Execute components, collect HTML
        ↓
4. Send Response      HTML + hydration data script
        ↓
5. Browser Parse      Display HTML immediately (fast first paint)
        ↓
6. Load JS Bundle     Download Melange-compiled code
        ↓
7. Hydrate            Attach event handlers, restore signals
        ↓
8. Interactive        App works as SPA from here
```

### Step-by-Step

**1. Route Definition:**
```ocaml
let venues_route = Route.create
  ~path:"/venues"
  ~loader:(fun _params ->
    let%lwt venues = Api.get_venues () in
    Lwt.return { venues }
  )
  ~component:Venues_page.make
```

**2. Server Handler (Dream example):**
```ocaml
let handler req =
  match Router.match_route routes (Dream.target req) with
  | Some route ->
    let%lwt data = Route.run_loader route req in
    let html = Solid_ml_ssr.render_to_string (fun () ->
      route.component ~data ()
    ) in
    let hydration = Solid_ml_ssr.get_hydration_script data in
    Dream.html (Layout.wrap ~hydration html)
  | None ->
    Dream.empty `Not_Found
```

**3. Generated HTML:**
```html
<!DOCTYPE html>
<html>
<body>
  <div id="app">
    <!-- Server-rendered with hydration markers -->
    <div data-hk="0">
      <input data-hk="1" type="text" placeholder="Search..." />
      <ul data-hk="2">
        <li data-hk="3">Venue One</li>
        <li data-hk="4">Venue Two</li>
      </ul>
    </div>
  </div>
  <script>window.__SOLID_ML_DATA__ = {"venues":[...]};</script>
  <script src="/static/app.js"></script>
</body>
</html>
```

**4. Client Entry Point:**
```ocaml
(* Compiled with Melange *)
let () =
  let root = Dom.get_element_by_id "app" in
  let data = Solid_ml_dom.get_hydration_data () in
  Solid_ml_dom.hydrate root (fun () ->
    Venues_page.make ~data ()
  )
```

**5. Hydration Process:**
- Walk the component tree and existing DOM simultaneously
- Match elements by `data-hk` markers
- Attach event handlers to existing elements
- Initialize signals with server-provided data
- DOM is NOT recreated, only "adopted"

---

## Router Design

### Route Definition

```ocaml
type 'a route = {
  path: string;
  loader: params -> 'a Lwt.t;
  component: data:'a -> unit -> element;
}

let routes = [
  Route.create ~path:"/" ~loader:(fun _ -> Lwt.return ()) 
    ~component:Home_page.make;
    
  Route.create ~path:"/venues" 
    ~loader:(fun _ -> 
      let%lwt venues = Api.get_venues () in
      Lwt.return { venues }
    )
    ~component:Venues_page.make;
    
  Route.create ~path:"/venues/:slug"
    ~loader:(fun params ->
      let slug = Params.get "slug" params in
      let%lwt venue = Api.get_venue slug in
      Lwt.return { venue }
    )
    ~component:Venue_detail_page.make;
]
```

### Client-Side Navigation

```ocaml
(* Router.Link intercepts clicks for SPA navigation *)
let navigation () =
  <nav>
    <Router.Link href="/">"Home"</Router.Link>
    <Router.Link href="/venues">"Venues"</Router.Link>
  </nav>

(* Programmatic navigation *)
let go_to_venue slug =
  Router.navigate ("/venues/" ^ slug)
```

### Data Loading States

```ocaml
let venues_page ~data () =
  <div>
    <h1>"Venues"</h1>
    (match data with
     | Loading -> <p>"Loading..."</p>
     | Error e -> <p class_="error">(string e)</p>
     | Ready venues -> <Venue_list venues />)
  </div>
```

---

## Consequences

### Benefits

- **Type Safety:** Full OCaml type checking for UI components
- **SEO:** Server renders complete HTML for search engines
- **Performance:** Fine-grained updates without virtual DOM overhead
- **Bundle Size:** Melange produces smaller JS than js_of_ocaml
- **DX:** MLX provides familiar JSX-like syntax
- **Interop:** Easy to call JavaScript libraries via Melange FFI

### Trade-offs

- **New Framework:** Maintenance burden, no existing community
- **Learning Curve:** Developers must understand fine-grained reactivity
- **Ecosystem:** Smaller than React/Vue, fewer ready-made components
- **Two Runtimes:** Must maintain solid-ml-ssr and solid-ml-dom in sync

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hydration mismatch | Medium | High | Strict deterministic rendering, extensive tests |
| Bundle size bloat | Low | Medium | Tree-shaking, minimal dependencies |
| Melange breaking changes | Low | Medium | Pin versions, integration tests |
| Performance issues | Low | High | Benchmark early, profile hot paths |

---

## Development Phases

### Phase 1: Reactive Core (2-3 weeks)

**Goal:** Working signals, effects, memos in native OCaml

**Tasks:**
- [x] Implement `Signal.create`, `get`, `set`, `update`
- [x] Implement dependency tracking via execution context stack
- [x] Implement `Effect.create` with auto-tracking
- [x] Implement `Effect.create_with_cleanup`
- [x] Implement `Memo.create`
- [x] Implement `batch` for batched updates
- [ ] Implement ownership tracking for cleanup
- [ ] Unit tests for all reactive primitives
- [ ] Example: counter in native OCaml (no browser)

**Deliverable:** `solid-ml` opam package

### Phase 2: Server Rendering (2 weeks)

**Goal:** Render MLX components to HTML string with hydration markers

**Tasks:**
- [x] Implement HTML element functions (div, p, input, etc.)
- [x] Implement `render_to_string`
- [x] Generate hydration markers (`data-hk` attributes)
- [ ] Serialize component state for hydration script
- [ ] Dream integration example
- [x] Test SSR output

**Deliverable:** `solid-ml-ssr` opam package

### Phase 3: Client Runtime (3-4 weeks)

**Goal:** Melange-compiled client with hydration

**Tasks:**
- [ ] Set up Melange build configuration
- [ ] DOM API bindings
- [ ] Implement DOM element functions
- [ ] Implement `render` (client-side from scratch)
- [ ] Implement `hydrate` (adopt existing DOM)
- [ ] Event handling and delegation
- [ ] `Signal.text`, `Signal.attr`, `Signal.show` helpers
- [ ] Test hydration correctness
- [ ] Example: interactive counter in browser

**Deliverable:** `solid-ml-dom` opam package

### Phase 4: Router (2-3 weeks)

**Goal:** SSR-aware routing with client-side navigation

**Tasks:**
- [ ] Route matching (static, params, wildcards)
- [ ] Route loaders (server-side data fetching)
- [ ] `Router.Link` component
- [ ] History API integration
- [ ] Client-side navigation without reload
- [ ] Scroll restoration
- [ ] Loading/error states

**Deliverable:** `solid-ml-router` opam package

### Phase 5: KaraokeCrowd Migration (3-4 weeks)

**Goal:** Port venues search page to solid-ml

**Tasks:**
- [ ] Integrate solid-ml into KaraokeCrowd build
- [ ] Port venue list component
- [ ] Port filter sidebar (days, type, price, status)
- [ ] Port text search
- [ ] Port location filter with geolocation
- [ ] Port pagination
- [ ] Connect to backend API
- [ ] SSR + hydration end-to-end
- [ ] Performance comparison

**Deliverable:** Working venues search with solid-ml

### Phase 6: Open Source Release (2 weeks)

**Goal:** Public v0.1 release

**Tasks:**
- [ ] README documentation
- [ ] API documentation
- [ ] More examples
- [ ] GitHub Actions CI
- [ ] opam package publishing
- [ ] License files (MIT)
- [ ] CONTRIBUTING.md
- [ ] Announcement post

**Deliverable:** Public release at github.com/makerprism/solid-ml

---

## Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Reactive Core | 2-3 weeks | 2-3 weeks |
| Phase 2: Server Rendering | 2 weeks | 4-5 weeks |
| Phase 3: Client Runtime | 3-4 weeks | 7-9 weeks |
| Phase 4: Router | 2-3 weeks | 9-12 weeks |
| Phase 5: Migration | 3-4 weeks | 12-16 weeks |
| Phase 6: Release | 2 weeks | 14-18 weeks |

**Total: ~4-5 months** to production-ready v0.1

---

## Key Implementation Files

| File | Purpose |
|------|---------|
| `lib/solid-ml/signal.ml` | Signals with dependency tracking |
| `lib/solid-ml/effect.ml` | Auto-tracking side effects |
| `lib/solid-ml/memo.ml` | Cached derived values |
| `lib/solid-ml/owner.ml` | Ownership and disposal |
| `lib/solid-ml-ssr/render.ml` | Server render to string |
| `lib/solid-ml-ssr/elements.ml` | HTML element functions |
| `lib/solid-ml-dom/hydrate.ml` | Client-side hydration |
| `lib/solid-ml-dom/elements.ml` | DOM element functions |
| `lib/solid-ml-dom/bindings/dom.ml` | Melange DOM bindings |
| `lib/solid-ml-router/router.ml` | Route matching and navigation |
| `lib/solid-ml-router/loader.ml` | Server-side data loading |

---

## References

- [SolidJS Documentation](https://www.solidjs.com/docs/latest)
- [SolidJS Source Code](https://github.com/solidjs/solid)
- [MLX Repository](https://github.com/ocaml-mlx/mlx)
- [Melange Documentation](https://melange.re/)
- [Melange MLX Template](https://github.com/andreypopp/melange-mlx-template)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2026 | Initial architecture document |

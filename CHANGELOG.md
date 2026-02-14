# Changelog

## 2026-01-30
- Change: Signal setters (`create`, `set`, `update`, and Unsafe variants) now return `unit` for SolidJS-like ergonomics.

## Unreleased

### Added
- Umbrella package `solid-ml` that pulls in solid-ml-server, SSR, router, browser, and MLX tooling.
- Fine-grained reactivity: signals, effects, memos, batch, owner, and context.
- Server-side rendering with HTML helpers and hydration markers.
- Client-side DOM runtime with Melange, hydration, and event handling.
- Router with route matching, params, wildcards, navigation, and link components.
- Suspense boundaries, ErrorBoundary, and Resource utilities.
- Browser-side render/hydrate APIs and navigation helpers.
- Typed Resource errors across solid-ml-server, solid-ml-router, and solid-ml-browser.
- Async Resource helpers with `create_with_error` and `create_async_with_error`.
- `read_suspense`/`get` accept `~error_to_string` for typed errors.
- Unique ID generation for SSR hydration.
- Example apps: counters, todo, router, SSR server, browser examples.
- Template runtime/PPX integration for MLX syntax.
- Router `use_search_params` hook with query setter (server and browser).
- Browser reactive core microtask deferral toggle (`Reactive_core.set_microtask_deferral`).
- `Resource.Async` for consistent async result-callback creation (router/browser).
- `Resource.get_or` helper and `Router_context` helpers (server/browser).

### Changed
- Removed token-based strict APIs; reactive primitives now follow SolidJS-style implicit runtime semantics. Create a per-request runtime with `Runtime.run` on servers to avoid cross-request state.
- Router matching now ranks by specificity (stable tie-break by order).
- Route param encoding/decoding now uses path-safe semantics (no `+` for spaces).
- ErrorBoundary now captures effect/memo errors in addition to render exceptions.
- Suspense now de-dups resource tracking by resource id.
- Browser attribute name sanitization matches SSR (unsafe chars replaced with `_`).
- Reactive text API renamed to `reactive_text*` (legacy aliases removed).
- Template `Tpl.show_when` preserves mounted subtrees while `when_` stays truthy; use reactive text bindings inside the subtree for updates.
- MLX template PPX now accepts common node-producing OCaml child expressions directly in dynamic templates (e.g. helper calls, `if`, `match`) without always requiring `Tpl.nodes`; explicit `Tpl.nodes` remains supported as an escape hatch.
- Examples were updated to demonstrate reduced `Tpl.nodes` ceremony where supported.

### Breaking (pre-release)
- No releases yet; treat all changes as breaking until 1.0.
- Renamed the main server package from `solid-ml` to `solid-ml-server`. Use `solid-ml` only as the umbrella meta package.
- Resource states now use `Loading/Ready/Error`; `Pending` is deprecated and treated as loading.
- Router components are now a functor only; SSR defaults moved to `Solid_ml_ssr.Router_components`.
- `Solid_ml_router.Resource.render_simple` moved to `Solid_ml_ssr.Router_resource`.

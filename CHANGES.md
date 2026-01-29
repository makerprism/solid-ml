# Changelog

## Unreleased

### Added
- Fine-grained reactivity: signals, effects, memos, batch, owner, and context.
- Server-side rendering with HTML helpers and hydration markers.
- Client-side DOM runtime with Melange, hydration, and event handling.
- Router with route matching, params, wildcards, navigation, and link components.
- Suspense boundaries, ErrorBoundary, and Resource utilities.
- Browser-side render/hydrate APIs and navigation helpers.
- Typed Resource errors across solid-ml, solid-ml-router, and solid-ml-browser.
- Async Resource helpers with `create_with_error` and `create_async_with_error`.
- `read_suspense`/`get` accept `~error_to_string` for typed errors.
- Unique ID generation for SSR hydration.
- Example apps: counters, todo, router, SSR server, browser examples.
- Template runtime/PPX integration for MLX syntax.
- Router `use_search_params` hook with query setter (server and browser).
- Browser reactive core microtask deferral toggle (`Reactive_core.set_microtask_deferral`).
- `Resource.Async` for consistent async result-callback creation (router/browser).
- `Resource.get_or` helper and `Router_context` helpers (server/browser).
- Migration guide at `docs/MIGRATIONS.md`.

### Changed
- Removed token-based strict APIs; reactive primitives now follow SolidJS-style implicit runtime semantics. Create a per-request runtime with `Runtime.run` on servers to avoid cross-request state.
- Router matching now ranks by specificity (stable tie-break by order).
- Route param encoding/decoding now uses path-safe semantics (no `+` for spaces).
- ErrorBoundary now captures effect/memo errors in addition to render exceptions.
- Suspense now de-dups resource tracking by resource id.
- Browser attribute name sanitization matches SSR (unsafe chars replaced with `_`).
- Reactive text API renamed to `reactive_text*` (legacy aliases removed).
- Template `Tpl.show_when` preserves mounted subtrees while `when_` stays truthy; use reactive text bindings inside the subtree for updates.

### Breaking (pre-release)
- No releases yet; treat all changes as breaking until 1.0.
- See `docs/MIGRATIONS.md` for common migrations.
- Resource states now use `Loading/Ready/Error`; `Pending` is deprecated and treated as loading.
- Router components are now a functor only; SSR defaults moved to `Solid_ml_ssr.Router_components`.
- `Solid_ml_router.Resource.render_simple` moved to `Solid_ml_ssr.Router_resource`.

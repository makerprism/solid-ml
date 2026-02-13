# RFC: MLX Surface DX Simplification

Status: Draft

Companion plan: `docs/rfc-mlx-implementation-plan.md`

## Goal

Make MLX authoring feel obvious on first use while preserving the current compiled-template performance model.

This RFC focuses on reducing syntax ceremony and configuration ambiguity, especially for teams writing SSR-first pages and component libraries.

## Motivation

Current MLX usage in a large real-world app snapshot reviewed during this RFC
shows repeated local workarounds that indicate friction in the public surface:

- 91/98 `.mlx` files define a local `module Tpl = struct ...` shim with:
  - `let text_once f = Html.text (f ())`
  - `let nodes f = f ()`
- `Tpl.text_once` appears about 900 times.
- `Tpl.nodes` appears about 270 times.

These patterns strongly suggest users want direct expression children and static text interpolation without explicit template markers.

## Problems (Current State)

1. Two-mode confusion

- Users must understand dialect setup and PPX setup as separate concerns.
- Failure mode is often discovered late with marker/runtime errors.

2. Verbose child syntax

- Frequent `(Tpl.text_once (fun () -> x))` for static values creates noise.
- Frequent `(Tpl.nodes (fun () -> ...))` for normal conditional/map expressions creates noise.

3. Fragile mental model

- Supported subset is broad but implicit; unsupported cases surface as PPX errors.
- Bare string children and some child expressions fail unexpectedly.

4. Internal constraints leak to users

- Single-root compiled-template constraint is visible in error behavior.

## Proposed Changes

### 1) One obvious setup path

Provide one recommended stanza everywhere in docs/examples:

```scheme
(preprocess (pps solid-ml-template-ppx))
```

And a short requirement sentence:

- "Use `.mlx` dialect for JSX syntax, and `solid-ml-template-ppx` for template lowering."

Additionally, improve startup diagnostics so a `.mlx` file with `Tpl.*` that is not lowered fails with a short, explicit compile-time message.

### 2) Auto-lowering for common child expressions

In MLX child position, add deterministic lowering rules:

- String/int/float expression child -> static text node (`Html.text` / `Html.int` / `Html.float`) when non-reactive.
- `unit -> string` thunk-like forms -> text slot (equivalent to current `Tpl.text`).
- Node expression child (`Html.node`) -> node slot where needed (equivalent to `Tpl.nodes`).

This removes most explicit `Tpl.text_once` and `Tpl.nodes` from user code.

### 3) First-class interpolation syntax

Support JSX-like interpolation directly in `.mlx`:

- Text interpolation: `{expr}`
- Attribute interpolation: `class_={expr}`

Semantics:

- In child position, `{expr}` lowers according to expression type/context.
- In attribute position:
  - plain value -> static attribute at render time
  - function thunk (`fun () -> ...`) -> reactive attribute binding

If introducing braces in `mlx-pp` is too large for one release, add a transitional mode that still accepts parenthesized children while documenting braces as preferred syntax.

### 4) Simplify control-flow surface

Allow ordinary OCaml conditional/list expressions in child position without `Tpl.nodes`:

- `if ... then <div>...</div> else Html.empty`
- `Html.fragment (List.map ...)`

Compiler should lower these into node slots when dynamic.

Keep `Tpl.show`, `Tpl.if_`, `Tpl.each_*` as advanced explicit primitives, not required for common UI flow.

### 5) Error messages oriented around user intent

Rewrite parser/type errors to include:

- what construct was found
- why it failed in template mode
- one concrete rewrite that compiles

Priority cases:

- bare string literal child
- unsupported child expression in dynamic template
- dynamic id/class collisions
- missing `~value` under bound `<select>` options

### 6) Optional fragment root support

Permit multiple top-level nodes in compiled templates by wrapping internally in an implementation container/fragment abstraction.

This removes a surprising "single root" gotcha while preserving hydration path stability internally.

## Backward Compatibility

- Existing `Tpl.*` APIs remain valid.
- Existing parenthesized child syntax remains valid.
- New interpolation syntax and auto-lowering are additive.
- Feature-gate braces interpolation initially if needed.

## Rollout Plan

Phase 1 (Low risk)

- Improve docs to one canonical setup path.
- Improve compile/runtime errors for unlowered markers.
- Keep behavior unchanged.

Phase 2 (High impact, moderate risk)

- Implement child auto-lowering rules.
- Allow common child expressions without explicit `Tpl.nodes`.

Phase 3 (Syntax upgrade)

- Add `{expr}` interpolation support in `.mlx` parser.
- Add attribute brace interpolation support.

Phase 4 (Ergonomic cleanup)

- Add optional codemod to rewrite:
  - `Tpl.text_once (fun () -> x)` -> `{x}`
  - `Tpl.nodes (fun () -> expr)` -> `{expr}`
  - local `module Tpl = struct ...` shims removed when no longer needed.

## Acceptance Criteria

1. A new MLX user can author a page without learning `Tpl.text_once` or `Tpl.nodes`.
2. Most common templates compile with direct expressions and conditionals in child position.
3. Error messages mention a single fix path and include a minimal valid example.
4. Existing projects compile unchanged.

## Non-Goals

- Replacing OCaml expression semantics.
- Adding a virtual DOM.
- Changing runtime reactivity behavior.

## Open Questions

1. Should brace interpolation require an opt-in flag for one release?
2. Should auto-lowering rely on typed AST (more precise) or untyped heuristics (faster to ship)?
3. Should fragment-root support be enabled in both SSR and browser backends at once, or staggered by backend?

## Appendix A: Proposed Parser/Lowering Rules (Concrete)

This appendix proposes deterministic lowering rules to remove ambiguity during
implementation.

### A.1 Child Position Lowering

Given MLX child slot `{expr}` (or transitional `(expr)`), lower by shape:

1. Literal constants

- `"text"` -> `Html.text "text"`
- `123` -> `Html.int 123`
- `3.14` -> `Html.float 3.14`

2. Explicit reactive text forms

- `Tpl.text (fun () -> s)` -> existing text slot lowering (unchanged)
- `Tpl.text_value s` -> existing static text slot lowering (unchanged)

3. Plain expression returning node

- If expression is already a node expression, keep as node child.
- If expression is conditional/match producing nodes, keep as node child.

4. Plain expression returning string-ish value

- In strict mode: require explicit `Html.text` or `Tpl.text`.
- In ergonomic mode: auto-wrap only well-defined primitive scalar types as text
  (`string`, `int`, `float`, optionally `bool`); all other types remain explicit
  to avoid surprising implicit conversions.

Recommendation: ship strict-by-default for safety in phase 2; add ergonomic mode
behind a flag, then flip after compatibility cycle.

### A.2 Attribute Position Lowering

For `name={expr}`:

1. Static values

- `class_={"a b"}` -> static `~class_`.
- `id={id_value}` -> static `~id`.

2. Thunk values

- `class_={fun () -> expr}` -> dynamic class attr (`Tpl.attr`/`Tpl.class_list` path).
- Boolean attrs with thunk -> `Some ""` / `None` optional attr semantics.

3. Collision rule

- Keep existing rejection for mixed static and dynamic writes to `id`/`class`.

### A.3 Control Flow

Accepted in child position without explicit wrappers:

- `if ... then node else node`
- `match ... with ... -> node`
- `Html.fragment (List.map ...)`

Compiler marks template dynamic if any branch depends on thunked reactive slots.

### A.4 Error Contract

All lowering errors must include:

- failing construct kind
- one-line reason
- one minimal rewrite example

Template:

```text
solid-ml-template-ppx: unsupported child expression `<kind>`.
Reason: <reason>
Try: <minimal compiling rewrite>
```

### A.5 Feature Flags

- `mlx_brace_interpolation` (default off in initial release)

Primitive child literal lowering is default-on. Keep only syntax-expansion work
behind explicit rollout controls.

## Appendix B: Implementation Checklist (Mapped to Current PPX)

This maps the proposal to concrete code locations in
`lib/solid-ml-template-ppx/solid_ml_template_ppx.ml`.

1. Child expression normalization

- Primary hook: `parse_element_expr` (child handling branch around dynamic/static
  child parsing).
- Related helper path: `extract_tpl_text_thunk`.
- Goal:
  - recognize transitional `(expr)` and future `{expr}` forms
  - classify child expressions into text/node/dynamic slot categories

2. Attribute interpolation and dynamic attr lowering

- Primary hook: `extract_dynamic_attr_binding`.
- Existing conflict guard: static `id/class_` with dynamic `Tpl.attr(_opt)` checks.
- Goal:
  - support `name={expr}` lowering plan
  - preserve boolean attr optional semantics and collision diagnostics

3. Marker detection and setup diagnostics

- Primary hooks:
  - `contains_tpl_markers`
  - `impl` (final unsupported-marker error)
- Goal:
  - keep errors actionable when lowering did not run or feature-gated syntax is used

4. AST emission path

- Primary hook: `compile_element_tree`.
- Goal:
  - ensure new child/attr classifications emit stable runtime bindings
  - keep current hydration marker behavior unchanged for existing code

5. Supported-subset and error examples

- Primary data: `supported_subset` string + specific `Location.raise_errorf` branches.
- Goal:
  - update subset docs and all failure messages together
  - add one concrete "Try:" rewrite in each new error path

6. Tests to add/update

- MLX integration tests:
  - `test_mlx/test_template_compiler_mlx.mlx`
  - `test_mlx/test_template_attr_mlx.mlx`
- Add cases for:
  - accepted child expression forms
  - attr interpolation lowering
  - setup/error diagnostics for unsupported markers
  - static/dynamic `id`/`class` collision behavior

7. Rollout guardrails

- Keep syntax-expansion additions behind feature flags first.
- Keep existing `Tpl.*` paths as baseline behavior.
- Require parity tests for SSR and browser backends before default-on.

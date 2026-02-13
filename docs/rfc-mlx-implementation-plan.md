# MLX DX Implementation Plan

This plan operationalizes `docs/rfc-mlx-dx.md` into implementable work items.

## Milestone 0: Baseline and Guardrails

1. Lock baseline tests

- Run and record current outputs for:
  - `test_mlx/test_template_compiler_mlx.mlx`
  - `test_mlx/test_template_attr_mlx.mlx`
- Ensure no behavior drift in existing `Tpl.*` paths.

2. Set default behavior baseline

- Make primitive child literal lowering default-on (`string`, `int`, `float`,
  `bool`) in template mode.
- Keep `brace_interpolation` as future staged work if needed.

## Milestone 1: Child Lowering Improvements (No New Syntax)

Target: remove common `Tpl.nodes` ceremony using existing `(expr)` form.

Implementation areas:

- `parse_element_expr` child branch
- `extract_tpl_text_thunk`
- `compile_element_tree`

Tasks:

1. Child classifier

- Add a dedicated classifier for child expressions in template mode:
  - explicit template markers (`Tpl.text`, `Tpl.nodes`, etc.)
  - intrinsic MLX elements
  - OCaml node expressions (`if`, `match`, `Html.fragment`, function calls returning nodes)
  - literals (`string`, `int`, `float`, `bool`)

2. Ergonomic lowering (default behavior)

- Lower primitive scalar child literals to static text nodes by default.
- Keep non-primitive expression handling explicit to avoid implicit coercion.

3. Diagnostics

- Add specific error branches for rejected child forms with a `Try:` rewrite.

Tests:

- Add positive/negative cases to `test_template_compiler_mlx.mlx`.

## Milestone 2: Attribute Interpolation Engine (Preparation)

Target: prepare lowerer for `name={expr}` without enabling braces yet.

Implementation areas:

- `extract_dynamic_attr_binding`
- static/dynamic attr merge checks

Tasks:

1. Internal attr representation cleanup

- Ensure static attr, dynamic thunk attr, and optional attr paths are normalized.

2. Collision behavior invariants

- Preserve current `id`/`class` conflict rejections.
- Add explicit tests for mixed static+dynamic collisions.

Tests:

- Extend `test_template_attr_mlx.mlx` with collision matrix.

## Milestone 3: Brace Interpolation Syntax

Target: support `{expr}` in child and attribute positions.

Implementation areas:

- MLX parser/dialect front-end integration
- PPX expression parser entrypoints

Tasks:

1. Child braces

- Parse `{expr}` in child position and forward to child classifier.

2. Attribute braces

- Parse `attr={expr}` and map to static/dynamic attr lowering.

3. Feature gating

- Enable only when `mlx_brace_interpolation=true`.

Tests:

- Add syntax acceptance tests for child/attr braces.
- Add failure tests when flag is off.

## Milestone 4: Documentation and Migration Tooling

1. Docs updates

- Update `docs/guide-mlx.md` with final recommended style.
- Keep `docs/guide-mlx-migration.md` with before/after mechanical rewrites.

2. Optional codemod

- Provide scripted rewrites for common forms:
  - `Tpl.text_once (fun () -> x)` -> `Html.text x`
  - `Tpl.nodes (fun () -> expr)` -> `expr`

## Review Checklist Per PR

- Existing templates compile unchanged except for newly accepted primitive
  child literals.
- Error messages include reason + one concrete rewrite.
- SSR/browser test parity maintained.

## Exit Criteria

- Users can author common conditionals/maps without `Tpl.nodes` wrappers.
- Migration path is documented and low-risk.
- No regressions in existing MLX compiled templates.

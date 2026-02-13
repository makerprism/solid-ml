# MLX Migration Playbook (Tpl Ceremony Reduction)

This guide gives mechanical, low-risk rewrites for existing MLX codebases that use
local `Tpl` shims (`text_once`, `nodes`) heavily.

Use this when you want cleaner templates without changing runtime behavior.

## Scope

Safe migrations in current surface:

- `Tpl.text_once (fun () -> x)` -> `Html.text x`
- remove no-op node wrapper: `Tpl.nodes (fun () -> expr)` -> `expr`
- remove local shim modules that only add `text_once` and `nodes`

Out of scope:

- changing reactive `Tpl.text` behavior
- introducing new interpolation syntax

## Step 1: Inventory

Count usage before changing anything:

```bash
rg -n "Tpl\.text_once|Tpl\.nodes|module Tpl = struct" lib --glob "**/*.mlx"
```

## Step 2: Replace Static Text Wrappers

Rewrite static text wrappers:

```ocaml
(* Before *)
(Tpl.text_once (fun () -> model.title))

(* After *)
(Html.text model.title)
```

Rules:

- Apply only when body is non-reactive/static from current render input.
- Keep `Tpl.text` unchanged for reactive reads (e.g. `Signal.get`, `Memo.get`).

## Step 3: Remove No-Op Node Wrappers

Rewrite node wrappers:

```ocaml
(* Before *)
(Tpl.nodes (fun () -> if show then <span>(Html.text "On")</span> else Html.empty))

(* After *)
(if show then <span>(Html.text "On")</span> else Html.empty)
```

```ocaml
(* Before *)
(Tpl.nodes (fun () -> Icons.Mic_icon.render ~class_:"w-4 h-4" ()))

(* After *)
(Icons.Mic_icon.render ~class_:"w-4 h-4" ())
```

Rules:

- This is safe when `nodes` is exactly `let nodes f = f ()`.
- Keep explicit `Tpl.nodes` if you use it as a readability marker for dynamic regions.

## Step 4: Drop Local Shim Modules

After replacements, remove local shim helpers when unused:

```ocaml
module Tpl = struct
  include Env.Tpl
  let text_once f = Html.text (f ())
  let nodes f = f ()
end
```

If you still need `Tpl.text` / `Tpl.attr*`, use `module Tpl = Env.Tpl` or keep
`include Env.Tpl` directly.

## Step 5: Verify

Build and test:

```bash
dune build @install
dune runtest
```

## Regression Checklist

- No behavior change for reactive text (`Tpl.text`) regions.
- No missing children after removing `Tpl.nodes` wrappers.
- No leftover references to removed `text_once` helper.
- MLX files still compile with `solid-ml-template-ppx` enabled.

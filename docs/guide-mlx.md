# MLX Guide

MLX provides JSX-like syntax for solid-ml components. Use it when you want
cleaner templates without giving up the OCaml HTML DSL. The `solid-ml` umbrella
package includes MLX by default.

## Setup

Add the MLX dialect to your `dune-project`:

```scheme
(lang dune 3.20)
(using melange 0.1)

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (preprocess
   (run mlx-pp %{input-file}))))
```

Enable the template PPX in each `dune` stanza that uses template-lowered
constructs (`Tpl.*` markers, compiled dynamic regions):

```scheme
(preprocess
 (pps solid-ml-template-ppx))
```

Canonical rule:

- `.mlx` syntax requires the `mlx` dialect in `dune-project`.
- Template lowering requires `solid-ml-template-ppx` in the local stanza.

If template lowering is missing or misconfigured, `Tpl.*` markers will not be
rewritten and can reach runtime.

## MLX vs HTML DSL

```ocaml
<div class_="container">
  <h1>(text "Welcome")</h1>
  <button onclick=(fun _ -> set_count 1)>
    (text "Increment")
  </button>
</div>
```

Equivalent DSL:

```ocaml
Html.div
  ~class_:"container"
  ~children:[
    Html.h1 ~children:[Html.text "Welcome"] ();
    Html.button
      ~onclick:(fun _ -> set_count 1)
      ~children:[Html.text "Increment"]
      ();
  ]
  ()
```

## Reactive Bindings

Use `Tpl.*` for reactive attributes and text:

```ocaml
<p>
  (Html.text "Count: ")
  (Tpl.text (fun () -> string_of_int (Signal.get count)))
</p>
```

Two-way input bindings:

```ocaml
<input
  type_="text"
  value=(Tpl.bind_input
    ~signal:(fun () -> Signal.get name)
    ~setter:set_name)
/>
```

## Migration Notes (Current Surface)

In existing codebases, you may see local shims like:

```ocaml
module Tpl = struct
  include Env.Tpl
  let text_once f = Html.text (f ())
  let nodes f = f ()
end
```

This pattern is valid, but it also signals that the author wanted less template
ceremony for static text and plain node expressions.

Recommended migration direction:

- Keep `Tpl.text` for truly reactive text.
- Use plain `Html.text` for static text.
- Use ordinary OCaml node expressions where possible.
- Keep `Tpl.nodes` for explicit dynamic-region intent.

Example:

```ocaml
(* Before *)
(Tpl.text_once (fun () -> model.title))

(* After *)
(Html.text model.title)
```

```ocaml
(* Before *)
(Tpl.nodes (fun () -> if show then <span>(Html.text "On")</span> else Html.empty))

(* After *)
(if show then <span>(Html.text "On")</span> else Html.empty)
```

## Notes

- MLX children currently use `(expr)` forms in compiled templates.
- Use `Tpl.class_list`, `Tpl.style`, `Tpl.attr`, and `Tpl.attr_opt` for reactive
  attributes.
- Avoid adjacent `Tpl.show`/`Tpl.if_` siblings under the same parent; wrap in
  a single `Tpl.nodes` with an `if/else`.

For large codebases, see `docs/guide-mlx-migration.md` for a mechanical
cleanup playbook.

Primitive child literals are lowered as static text in template mode. For
example, `(42)`, `(3.5)`, `(true)`, and `("hello")` are valid child forms.

`{expr}` interpolation is not supported yet in this stack. Use `(expr)` in child
position for now.

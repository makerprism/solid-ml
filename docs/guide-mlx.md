# MLX Guide

MLX provides JSX-like syntax for solid-ml-server components. Use it when you want
cleaner templates without giving up the OCaml HTML DSL.

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

Enable the template PPX where you want `{expr}` interpolation:

```scheme
(preprocess
 (pps solid-ml-template-ppx))
```

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

## Notes

- MLX children must use `(expr)` unless the template PPX is enabled.
- Use `Tpl.class_list`, `Tpl.style`, `Tpl.attr`, and `Tpl.attr_opt` for reactive
  attributes.
- Avoid adjacent `Tpl.show`/`Tpl.if_` siblings under the same parent; wrap in
  a single `Tpl.nodes` with an `if/else`.

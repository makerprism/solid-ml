(lang dune 3.17)
(using melange 0.1)

(name solid-ml)

(version 0.1.0)

(license MIT)

(authors "Makerprism")

(maintainers "Makerprism")

(source (github makerprism/solid-ml))

(generate_opam_files true)

; MLX support (JSX-like syntax)
; This makes dune treat `.mlx` as OCaml implementation files.
(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (preprocess
   (run mlx-pp %{input-file}))))

; Internal package - DO NOT use directly
(package
 (name solid-ml-internal)
 (synopsis "Internal reactive primitives for solid-ml (do not use directly)")
 (description "Functor-based reactive internals shared between server and browser. Use solid-ml or solid-ml-browser instead.")
  (depends
   (ocaml (>= 4.14.0))
   (dune (< 3.21))))

; Server-side reactive framework
(package
 (name solid-ml)
 (synopsis "Reactive web framework for OCaml (server-side)")
 (description "Fine-grained reactivity with signals, effects, and memos. Server-side with Domain-local storage for thread safety. Inspired by SolidJS.")
  (depends
   (ocaml (>= 5.0.0))
   (solid-ml-internal (= :version))
   (solid-ml-template-runtime (= :version))
   (dune (< 3.21))))

; Server-side rendering
(package
 (name solid-ml-ssr)
 (synopsis "Server-side rendering for solid-ml")
 (description "Render solid-ml components to HTML strings for SSR.")
 (allow_empty)
  (depends
   (ocaml (>= 4.14.0))
   (solid-ml (= :version))
   (dune (< 3.21))))

; Browser-side reactive framework (Melange)
(package
 (name solid-ml-browser)
 (synopsis "Reactive web framework for OCaml (browser-side)")
 (description "Fine-grained reactivity with signals, effects, and memos. Browser-side via Melange. Inspired by SolidJS.")
 (allow_empty)
  (depends
   (ocaml (>= 4.14.0))
   (solid-ml-internal (= :version))
   (solid-ml-template-runtime (= :version))
   (melange (>= 3.0.0))
   (dune (< 3.21))))

; Router (SSR-aware)
(package
 (name solid-ml-router)
 (synopsis "SSR-aware routing for solid-ml")
 (description "Routing with server-side data loaders and client-side navigation.")
 (allow_empty)
  (depends
   (ocaml (>= 4.14.0))
   (solid-ml (= :version))
   (solid-ml-ssr (= :version))
   (dune (< 3.21))))

; Template runtime interfaces (shared)
(package
 (name solid-ml-template-runtime)
 (synopsis "Template runtime interfaces for solid-ml")
 (description "Shared runtime interfaces and types for SolidJS-style template compilation.")
 (allow_empty)
  (depends
   (ocaml (>= 4.14.0))
   (dune (< 3.21))))

; Template compiler PPX (build-time)
(package
 (name solid-ml-template-ppx)
 (synopsis "Template compiler PPX for solid-ml")
 (description "PPX rewriter for SolidJS-style template compilation targeting solid-ml Html backends.")
 (allow_empty)
  (depends
    (ocaml (>= 4.14.0))
    (ppxlib (>= 0.27.0))
    (mlx (>= 0.11))
   (dune (< 3.21))))

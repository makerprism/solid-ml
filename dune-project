(lang dune 3.16)
(using melange 0.1)

(name solid-ml)

(version 0.1.0)

(license MIT)

(authors "Makerprism")

(maintainers "Makerprism")

(source (github makerprism/solid-ml))

(generate_opam_files true)

(package
 (name solid-ml)
 (synopsis "Core reactive primitives for solid-ml")
 (description "Fine-grained reactivity with signals, effects, and memos. Inspired by SolidJS.")
 (depends
  (ocaml (>= 4.14.0))))

(package
 (name solid-ml-html)
 (synopsis "Server-side rendering for solid-ml")
 (description "Render solid-ml components to HTML strings for SSR.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml (= :version))))

(package
 (name solid-ml-dom)
 (synopsis "Client-side rendering and hydration for solid-ml")
 (description "DOM rendering and hydration for solid-ml, compiled with Melange.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml (= :version))
  (melange (>= 3.0.0))))

(package
 (name solid-ml-router)
 (synopsis "SSR-aware routing for solid-ml")
 (description "Routing with server-side data loaders and client-side navigation.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml (= :version))))

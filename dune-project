(lang dune 3.16)
(using melange 0.1)

(name solid-ml)

(version 0.1.0)

(license MIT)

(authors "Makerprism")

(maintainers "Makerprism")

(source (github makerprism/solid-ml))

(generate_opam_files true)

; Internal package - DO NOT use directly
(package
 (name solid-ml-internal)
 (synopsis "Internal reactive primitives for solid-ml (do not use directly)")
 (description "Functor-based reactive internals shared between server and browser. Use solid-ml or solid-ml-browser instead.")
 (depends
  (ocaml (>= 4.14.0))))

; Server-side reactive framework
(package
 (name solid-ml)
 (synopsis "Reactive web framework for OCaml (server-side)")
 (description "Fine-grained reactivity with signals, effects, and memos. Server-side with Domain-local storage for thread safety. Inspired by SolidJS.")
 (depends
  (ocaml (>= 5.0.0))
  (solid-ml-internal (= :version))))

; Server-side rendering
(package
 (name solid-ml-ssr)
 (synopsis "Server-side rendering for solid-ml")
 (description "Render solid-ml components to HTML strings for SSR.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml (= :version))))

; Browser-side reactive framework (Melange)
(package
 (name solid-ml-browser)
 (synopsis "Reactive web framework for OCaml (browser-side)")
 (description "Fine-grained reactivity with signals, effects, and memos. Browser-side via Melange. Inspired by SolidJS.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml-internal (= :version))
  (melange (>= 3.0.0))))

; Router (SSR-aware)
(package
 (name solid-ml-router)
 (synopsis "SSR-aware routing for solid-ml")
 (description "Routing with server-side data loaders and client-side navigation.")
 (allow_empty)
 (depends
  (ocaml (>= 4.14.0))
  (solid-ml (= :version))
  (solid-ml-ssr (= :version))))

; Example SSR App
(package
 (name full-ssr-app)
 (synopsis "Example SSR app for solid-ml")
 (description "A full-stack SSR example using Dream and solid-ml.")
 (allow_empty)
 (depends
  (ocaml (= 5.2.1))
  (dream (>= 1.0.0~alpha8))
  (solid-ml (= :version))
  (solid-ml-ssr (= :version))))



# Dune Package Demo

This example shows how to consume the `solid-ml` libraries from a standalone
`dune` project. It renders a simple HTML page with an embedded SVG logo using the
server-side rendering helpers.

## Project Layout

```
examples/dune_package_demo/
├── dune-project
└── src/
    ├── dune
    └── main.ml
```

- `dune-project` declares a local package named `dune-package-demo` that depends on
  `solid-ml` and `solid-ml-ssr`.
- `src/main.ml` renders a simple component to an HTML document and prints it to stdout.

## Building and Running

From the repository root, run:

```bash
# Build the executable
dune build examples/dune_package_demo/src/main.exe

# Execute the demo (prints HTML to stdout)
dune exec examples/dune_package_demo/src/main.exe
```

You can redirect the output into a file if desired:

```bash
dune exec examples/dune_package_demo/src/main.exe > output.html
```

## Minimum Dune Version

The repository (and this example) use features available in **Dune 3.16** or later,
matching the root `dune-project` file. Ensure you have at least Dune 3.16 installed
before building the demo.

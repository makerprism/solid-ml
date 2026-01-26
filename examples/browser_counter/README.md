# Browser Counter Example

This example demonstrates solid-ml-browser running in the browser, compiled to JavaScript via Melange.

## Quick Start

```bash
# From the repository root:

# 1. Build the example
make example-browser

# 2. Serve and open in browser
make serve
# Then open http://localhost:8000/browser_counter/
```

## What This Example Shows

### Counter Component
- Signal for count state
- Memo for derived value (doubled)
- Reactive text nodes that update automatically
- Button click handlers

### Todo List Component
- List state with signals
- Two-way input binding
- Reactive list rendering (keyed updates)
- Event handlers (click, keydown, change)
- Conditional styling based on completion status

If you are using MLX templates in your project, consider using
`Tpl.bind_input` and `Tpl.each_keyed` instead of the imperative binding
shown here.

## Files

```
browser_counter/
├── counter.ml   # OCaml source with components
├── dune         # Build configuration for Melange
├── index.html   # HTML page that loads the compiled JS
└── dist/        # Built JS output (created by make)
```

## Notes

- Requires Node.js for esbuild bundling
- The compiled JavaScript uses ES6 modules
- All reactive updates happen automatically when signals change

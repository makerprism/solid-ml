# Browser Counter Example

This example demonstrates solid-ml-browser running in the browser, compiled to JavaScript via Melange.

## Quick Start

```bash
# From the repository root:

# 1. One-time setup (installs Melange via esy)
make setup

# 2. Build the example
make example-browser

# 3. Open in browser (URL shown after build)
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
- Reactive list rendering
- Event handlers (click, keydown, change)
- Conditional styling based on completion status

## Files

```
browser_counter/
├── counter.ml   # OCaml source with components
├── dune         # Build configuration for Melange
├── index.html   # HTML page that loads the compiled JS
└── dist/        # Built JS output (created by make)
```

## Notes

- Requires [esy](https://esy.sh/) for Melange: `npm install -g esy`
- The compiled JavaScript uses ES6 modules
- All reactive updates happen automatically when signals change

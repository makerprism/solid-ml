# Browser Counter Example

This example demonstrates solid-ml-dom running in the browser, compiled to JavaScript via Melange.

## Prerequisites

Install Melange:

```bash
opam install melange
```

## Building

```bash
# From the repository root
dune build @melange
```

This compiles the OCaml code to JavaScript in:
```
_build/default/examples/browser_counter/output/
```

## Running

1. Build with `dune build @melange`
2. Open `index.html` in a browser
3. The counter and todo list should be interactive

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

## Code Structure

```
browser_counter/
├── counter.ml      # OCaml source with components
├── dune           # Build configuration for Melange
├── index.html     # HTML page that loads the compiled JS
└── README.md      # This file
```

## Notes

- The example is marked as optional in the dune file and only builds when Melange is installed
- The compiled JavaScript uses ES6 modules
- All reactive updates happen automatically when signals change

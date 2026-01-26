# solid-ml Cleanup Example

This example demonstrates the three cleanup APIs available in solid-ml and how to use them to prevent memory leaks in single-page applications (SPAs).

## Cleanup APIs

### 1. `Effect.create_with_cleanup`

Effects that return cleanup functions. The cleanup runs before the effect re-executes and when the owning scope is disposed.

```ocaml
Reactive.Effect.create_with_cleanup (fun () ->
  (* Set up resource *)
  let interval_id = Dom.set_interval ... in

  (* Return cleanup function *)
  fun () ->
    Dom.clear_interval interval_id
)
```

### 2. `Owner.on_cleanup`

Register cleanup functions with the current owner. The cleanup runs when the owning scope is disposed.

```ocaml
Owner.on_cleanup (fun () ->
  (* Clean up resources *)
  Dom.log "Cleaning up!"
)
```

### 3. `Render.render` / `Render.hydrate` dispose function

The render and hydrate functions return a dispose function that cleans up all effects and event handlers.

```ocaml
let dispose = Render.render root component in

(* Later: clean up on page unload *)
Dom.on_unload (fun _ ->
  dispose ()
)
```

## Why Cleanup Matters

In SPAs, proper cleanup is critical to prevent memory leaks:

- **Event listeners** not removed cause memory leaks
- **Timers/intervals** not cleared continue running
- **DOM references** prevent garbage collection
- **Network requests** may complete after navigation

## Building and Running

```bash
# From the repository root
dune build @melange

# Serve the examples directory
cd examples
python3 -m http.server 8000

# Open in browser
# http://localhost:8000/cleanup_example/
```

## What to Look For

1. Open the browser console (F12)
2. Watch for log messages when:
   - The page loads
   - You add resources (shows Owner.on_cleanup registration)
   - You navigate away from the page (shows render dispose)

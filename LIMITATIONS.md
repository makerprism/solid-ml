# solid-ml Limitations

Short list of real constraints to keep in mind.

## Core Constraints

1. **Signals cannot be shared across runtimes/domains.** Create signals inside
   the `Runtime.run` scope that uses them.
2. **Effects and memos are synchronous.** Async work should happen before
   rendering or through Resource helpers.
3. **No streaming SSR.** Rendering is buffered (`Render.to_string`).
4. **Hydration requires identical structure.** Server and client trees must
   match exactly for adoption to succeed.
5. **Hydration markers are HTML comments.** In some CSS layouts, comment nodes
   can affect spacing; wrap reactive text in a `<span>` if needed.
6. **Manual cleanup is required for roots you create.** `Owner.create_root`
   must be disposed to avoid leaks; SSR helpers dispose automatically.

## Browser Build Constraints

- `solid-ml-browser` requires Melange and Node.js for bundling.

## Design Differences (from SolidJS)

- Effects run synchronously (no microtask deferral by default).
- Memos use structural equality by default (override with `~equals`).
- No concurrent rendering or transitions.

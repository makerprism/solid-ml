# Examples

Quick index of runnable examples and their primary entrypoints.

## Native / Server

- `parallel` - Domain-local runtime isolation demo
  - Build: `make example-parallel`
- `full_ssr_app` - Full SSR + hydration app
  - Build: `make example-full-ssr`
- `ssr_api_app` - SSR with shared API module
  - Build: `make example-ssr-api-app`
- `state_hydration_demo` - State transfer and hydration
  - Build: `dune build examples/state_hydration_demo/server/main.exe`
- `dune_package_demo` - Example of consuming packages from a local dune project
  - Build: `dune build examples/dune_package_demo/src/main.exe`

## Browser

- `browser_counter` - Browser counter + todo
  - Build: `make browser-examples`
- `browser_router` - Browser router demo
  - Build: `make browser-examples`
- `cleanup_example` - Cleanup patterns in browser runtime
  - Build: `make browser-examples`

## Docker (optional)

- `ssr_api_app` - Canonical Docker build (SSR + Melange client bundle)
  - Build: `docker build -t solid-ml-ssr-api -f examples/ssr_api_app/Dockerfile .`
  - Notes: Builds Melange output with dune, then bundles `client.js` via esbuild for the static dir.

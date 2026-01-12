# solid-ml Makefile
#
# Quick start:
#   make example-counter    # Run the counter example
#   make example-router     # Run the router example  
#   make test               # Run all tests
#
# For browser examples:
#   make serve              # Build and serve browser examples at http://localhost:8000

.PHONY: build test clean \
        example-counter example-todo example-router example-parallel example-ssr-server \
        example-browser example-browser-router browser-examples browser-tests serve \
        example-full-ssr example-full-ssr-client \
        example-ssr-api example-ssr-api-client \
        example-ssr-hydration-docker

# ==============================================================================
# Development
# ==============================================================================

# Build all packages
build:
	dune build @check --force 2>/dev/null || dune build lib/solid-ml lib/solid-ml-html lib/solid-ml-router

# Run all tests
test:
	dune runtest

# Clean all build artifacts
clean:
	dune clean
	rm -rf examples/browser_counter/dist examples/browser_router/dist

# ==============================================================================
# Native Examples - just run these!
# ==============================================================================

example-counter:
	@echo "=== Running Counter Example ==="
	@dune exec examples/counter/counter.exe

example-todo:
	@echo "=== Running Todo Example ==="
	@dune exec examples/todo/todo.exe

example-router:
	@echo "=== Running Router Example ==="
	@dune exec examples/router/router.exe

example-parallel:
	@echo "=== Running Parallel Domains Example ==="
	@dune exec examples/parallel/parallel.exe

example-ssr-server:
	@echo "=== Starting SSR Server Example ==="
	@echo "Set PORT=XXXX to use a different port (default: 8080)"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@dune exec examples/ssr_server/server.exe || stty sane

# Build full SSR client
example-full-ssr-client:
	@echo "Building full SSR client..."
	@dune build @examples/full_ssr_app/client/melange
	@mkdir -p examples/full_ssr_app/static
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/full_ssr_app/client/output && \
		npx esbuild examples/full_ssr_app/client/client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/full_ssr_app/static/client.js --format=esm 2>/dev/null
	@echo "Client built: examples/full_ssr_app/static/client.js"

# Run full SSR example (server + client)
example-full-ssr: example-full-ssr-client
	@echo ""
	@echo "=== Starting Full SSR Example ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@dune exec examples/full_ssr_app/server/server.exe || stty sane

# Build SSR API client
example-ssr-api-client:
	@echo "Building SSR API client..."
	@dune build @examples/ssr_api_app/client/melange
	@mkdir -p examples/ssr_api_app/static
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/ssr_api_app/client/output && \
		npx esbuild examples/ssr_api_app/client/client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/ssr_api_app/static/client.js --format=esm 2>/dev/null
	@echo "Client built: examples/ssr_api_app/static/client.js"

# Run SSR API example (server + client with REST API fetching)
example-ssr-api: example-ssr-api-client
	@echo ""
	@echo "=== Starting SSR API Example ==="
	@echo "Visit http://localhost:8080"
	@echo "This app fetches data from JSONPlaceholder API"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@dune exec examples/ssr_api_app/server.exe || stty sane

# Build and run the Docker-based SSR + hydration demo
example-ssr-hydration-docker:
	@echo "=== Building Docker image: solid-ml-ssr-hydration ==="
	@docker build -t solid-ml-ssr-hydration -f examples/ssr_hydration_docker/Dockerfile .
	@echo ""
	@echo "=== Running container ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop (container will be removed)"
	@echo ""
	@docker run --rm -p 8080:8080 solid-ml-ssr-hydration || stty sane

# Run all native examples (except long-running servers)
examples: example-counter example-todo example-router example-parallel

# ==============================================================================
# Browser Development (requires Node.js for esbuild bundling)
# ==============================================================================

# Build browser counter example
example-browser:
	@echo "Building browser counter example..."
	@dune build @examples/browser_counter/melange
	@mkdir -p examples/browser_counter/dist
	@rm -f examples/browser_counter/dist/counter.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/browser_counter/output && \
		npx esbuild examples/browser_counter/counter.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_counter/dist/counter.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_counter/"

# Build browser router example
example-browser-router:
	@echo "Building browser router example..."
	@dune build @examples/browser_router/melange
	@mkdir -p examples/browser_router/dist
	@rm -f examples/browser_router/dist/router_demo.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/browser_router/output && \
		npx esbuild examples/browser_router/router_demo.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_router/dist/router_demo.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_router/"

# Build all browser examples
browser-examples: example-browser example-browser-router
	@echo ""
	@echo "All browser examples built! Run 'make serve' to view them."

# Serve browser examples (required due to ES module CORS restrictions)
serve: browser-examples
	@echo ""
	@echo "=== Serving Browser Examples ==="
	@echo "Open http://localhost:8000 in your browser"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@python3 -m http.server 8000 -d examples || stty sane

# Run browser tests (requires Node.js)
browser-tests:
	@echo "Running browser tests..."
	@dune build @test_browser/melange
	@node _build/default/test_browser/output/test_browser/test_reactive.js

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo "solid-ml Makefile"
	@echo ""
	@echo "Development:"
	@echo "  make build              - Build all packages"
	@echo "  make test               - Run all tests"
	@echo "  make clean              - Remove build artifacts"
	@echo ""
	@echo "Native examples:"
	@echo "  make example-counter    - Run counter example"
	@echo "  make example-todo       - Run todo example"
	@echo "  make example-router     - Run router example"
	@echo "  make example-parallel   - Run parallel domains example"
	@echo "  make examples           - Run all native examples"
	@echo ""
	@echo "Full SSR (requires: dream + cohttp-lwt-unix, or Docker):"
	@echo "  make example-full-ssr            - SSR with counter and todos"
	@echo "  make example-ssr-api             - SSR with REST API data fetching"
	@echo "  make example-ssr-hydration-docker - Build + run Docker SSR hydration demo"
	@echo ""
	@echo "Browser development (requires Node.js for esbuild):"
	@echo "  make serve               - Build and serve browser examples"
	@echo "  make browser-examples    - Build all browser examples"
	@echo "  make browser-tests       - Run browser tests"

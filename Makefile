# solid-ml Makefile
#
# Quick start:
#   make example-counter    # Run the counter example
#   make example-router     # Run the router example  
#   make test               # Run all tests
#
# For browser examples (requires esy):
#   make setup              # One-time setup: install esy dependencies
#   make serve              # Build and serve browser examples at http://localhost:8000

.PHONY: build test clean setup \
        example-counter example-todo example-router example-parallel example-ssr-server \
        example-browser example-browser-router browser-examples browser-tests serve \
        example-full-ssr example-full-ssr-client \
        example-ssr-api example-ssr-api-client

# ==============================================================================
# Native Development (no extra dependencies needed)
# ==============================================================================

# Build all native packages
build:
	dune build @check --force 2>/dev/null || dune build lib/solid-ml lib/solid-ml-html lib/solid-ml-router

# Run all native tests
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
	@ENABLE_DREAM=1 dune exec examples/ssr_server/server.exe || stty sane

# Build full SSR client
example-full-ssr-client: check-esy
	@echo "Building full SSR client..."
	@esy dune build examples/full_ssr_app/client/output/examples/full_ssr_app/client/client.js 2>/dev/null || \
		(echo "Error: Run 'make setup' first to install dependencies" && exit 1)
	@mkdir -p examples/full_ssr_app/static
	@echo "Bundling with esbuild..."
	@cd $$(esy echo '#{self.target_dir}')/default/examples/full_ssr_app/client/output && \
		npx esbuild examples/full_ssr_app/client/client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/full_ssr_app/static/client.js --format=esm 2>/dev/null
	@echo "Client built: examples/full_ssr_app/static/client.js"

# Run full SSR example (server + client)
example-full-ssr: example-full-ssr-client
	@echo ""
	@echo "=== Starting Full SSR Example ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@ENABLE_DREAM=1 dune exec examples/full_ssr_app/server.exe || stty sane

# Build SSR API client
example-ssr-api-client: check-esy
	@echo "Building SSR API client..."
	@esy dune build examples/ssr_api_app/client/output/examples/ssr_api_app/client/client.js 2>/dev/null || \
		(echo "Error: Run 'make setup' first to install dependencies" && exit 1)
	@mkdir -p examples/ssr_api_app/static
	@echo "Bundling with esbuild..."
	@cd $$(esy echo '#{self.target_dir}')/default/examples/ssr_api_app/client/output && \
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
	@ENABLE_DREAM=1 dune exec examples/ssr_api_app/server.exe || stty sane

# Run all native examples (except long-running servers)
examples: example-counter example-todo example-router example-parallel

# ==============================================================================
# Browser Development (requires esy + Node.js)
# ==============================================================================

# Check if esy is installed
check-esy:
	@which esy > /dev/null || (echo "Error: esy not found. Install with: npm install -g esy" && exit 1)

# One-time setup: install esy dependencies (includes Melange)
setup: check-esy
	@echo "Installing dependencies (this may take a few minutes on first run)..."
	esy install
	@echo "Done! You can now run: make example-browser"

# Build browser counter example
example-browser: check-esy
	@echo "Building browser counter example..."
	@esy dune build examples/browser_counter/output/examples/browser_counter/counter.js 2>/dev/null || \
		(echo "Error: Run 'make setup' first to install dependencies" && exit 1)
	@mkdir -p examples/browser_counter/dist
	@rm -f examples/browser_counter/dist/counter.js
	@echo "Bundling with esbuild..."
	@cd $$(esy echo '#{self.target_dir}')/default/examples/browser_counter/output && \
		npx esbuild examples/browser_counter/counter.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_counter/dist/counter.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_counter/"

# Build browser router example
example-browser-router: check-esy
	@echo "Building browser router example..."
	@esy dune build examples/browser_router/output/examples/browser_router/router_demo.js 2>/dev/null || \
		(echo "Error: Run 'make setup' first to install dependencies" && exit 1)
	@mkdir -p examples/browser_router/dist
	@rm -f examples/browser_router/dist/router_demo.js
	@echo "Bundling with esbuild..."
	@cd $$(esy echo '#{self.target_dir}')/default/examples/browser_router/output && \
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
browser-tests: check-esy
	@echo "Running browser tests..."
	@esy dune build @test_browser/melange
	@esy sh -c 'node $$cur__target_dir/default/test_browser/output/test_browser/test_reactive.js'

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo "solid-ml Makefile"
	@echo ""
	@echo "Native development (no extra setup needed):"
	@echo "  make build              - Build native packages"
	@echo "  make test               - Run native tests"
	@echo "  make example-counter    - Run counter example"
	@echo "  make example-todo       - Run todo example"
	@echo "  make example-router     - Run router example"
	@echo "  make examples           - Run all native examples"
	@echo ""
	@echo "Full SSR (requires: dream + cohttp-lwt-unix + esy):"
	@echo "  make example-full-ssr   - SSR with counter and todos"
	@echo "  make example-ssr-api    - SSR with REST API data fetching"
	@echo ""
	@echo "Browser development (requires: npm install -g esy):"
	@echo "  make setup               - Install esy dependencies (one-time)"
	@echo "  make serve               - Build and serve browser examples"
	@echo "  make browser-examples    - Build all browser examples"
	@echo "  make browser-tests       - Run browser tests"
	@echo ""
	@echo "Other:"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make help            - Show this help"

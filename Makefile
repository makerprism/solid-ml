# solid-ml Makefile
#
# Quick start:
#   make example-counter    # Run the counter example
#   make example-router     # Run the router example
#   make test               # Run all tests
#
# For browser examples (requires esy):
#   make setup              # One-time setup: install esy dependencies
#   make example-browser    # Build and serve browser example

.PHONY: build test clean setup \
        example-counter example-todo example-router example-parallel example-ssr-server \
        example-browser example-browser-router browser-examples browser-tests

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
	@echo "Visit http://localhost:8080 in your browser"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@dune exec examples/ssr_server/server.exe

# Run all native examples (except ssr-server which is long-running)
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
		npx esbuild examples/browser_counter/counter.js --bundle --outfile=$(PWD)/examples/browser_counter/dist/counter.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Open in browser:"
	@echo "  file://$(PWD)/examples/browser_counter/index.html"

# Build browser router example
example-browser-router: check-esy
	@echo "Building browser router example..."
	@esy dune build examples/browser_router/output/examples/browser_router/router_demo.js 2>/dev/null || \
		(echo "Error: Run 'make setup' first to install dependencies" && exit 1)
	@mkdir -p examples/browser_router/dist
	@rm -f examples/browser_router/dist/router_demo.js
	@echo "Bundling with esbuild..."
	@cd $$(esy echo '#{self.target_dir}')/default/examples/browser_router/output && \
		npx esbuild examples/browser_router/router_demo.js --bundle --outfile=$(PWD)/examples/browser_router/dist/router_demo.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Open in browser:"
	@echo "  file://$(PWD)/examples/browser_router/index.html"
	@echo ""
	@echo "NOTE: For routing to work properly, use a local server:"
	@echo "  python3 -m http.server 8001 -d examples/browser_router"
	@echo "  Then open: http://localhost:8001"

# Build all browser examples
browser-examples: example-browser example-browser-router
	@echo ""
	@echo "All browser examples built!"
	@echo ""
	@echo "Start a server to view all examples:"
	@echo "  python3 -m http.server 8000 -d examples"
	@echo "  Then open: http://localhost:8000"

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
	@echo "  make example-ssr-server - Start SSR server (requires dream)"
	@echo "  make examples           - Run all native examples"
	@echo ""
	@echo "Browser development (requires: npm install -g esy):"
	@echo "  make setup               - Install esy dependencies (one-time)"
	@echo "  make example-browser     - Build counter+todo browser example"
	@echo "  make example-browser-router - Build router browser example"
	@echo "  make browser-examples    - Build all browser examples"
	@echo "  make browser-tests       - Run browser tests"
	@echo ""
	@echo "Other:"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make help            - Show this help"

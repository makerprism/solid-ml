# solid-ml Makefile
#
# NOTE: This project uses dune 3.20.2 installed at /usr/bin/dune.
# The dune-project uses (lang dune 3.17) for compatibility.
# We use a fixed path instead of relying on PATH to avoid issues with opam switch
# environments where different dune versions could be inadvertently picked up.
# Override with: make DUNE=/path/to/dune <target>
#
# Quick start:
#   make example-counter    # Run the counter example
#   make example-router     # Run the router example  
#   make test               # Run all tests
#
# For browser examples:
#   make serve              # Build and serve browser examples at http://localhost:8000

.PHONY: build test clean \
        example-counter example-todo example-router example-parallel example-ssr-server example-ssr-server-docker \
        example-browser example-browser-router browser-examples browser-tests browser-tests-headless serve \
        example-full-ssr example-full-ssr-client example-full-ssr-docker \
        example-ssr-api example-ssr-api-client example-ssr-api-local example-ssr-api-docker \
        example-ssr-hydration-docker

PORT ?= 8080
DUNE ?= /usr/bin/dune

# ==============================================================================
# Development
# ==============================================================================

# Build all packages
build:
	$(DUNE) build @check --force 2>/dev/null || $(DUNE) build lib/solid-ml lib/solid-ml-ssr lib/solid-ml-router lib/solid-ml-internal

# Run all tests
test:
	$(DUNE) runtest

# Clean all build artifacts
clean:
	$(DUNE) clean
	rm -rf examples/browser_counter/dist examples/browser_router/dist

# ==============================================================================
# Native Examples - just run these!
# ==============================================================================

example-counter:
	@echo "=== Running Counter Example ==="
	@$(DUNE) exec examples/counter/counter.exe

example-todo:
	@echo "=== Running Todo Example ==="
	@$(DUNE) exec examples/todo/todo.exe

example-router:
	@echo "=== Running Router Example ==="
	@$(DUNE) exec examples/router/router.exe

example-parallel:
	@echo "=== Running Parallel Domains Example ==="
	@$(DUNE) exec examples/parallel/parallel.exe

example-ssr-server:
	@echo "=== Starting SSR Server Example ==="
	@echo "Set PORT=XXXX to use a different port (default: 8080)"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@$(DUNE) exec examples/ssr_server/server.exe || stty sane

# Build and run SSR server example via Docker
example-ssr-server-docker:
	@echo "=== Building Docker image: solid-ml-ssr-server ==="
	@docker build -t solid-ml-ssr-server -f examples/ssr_server/Dockerfile .
	@echo ""
	@echo "=== Running container ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop (container will be removed)"
	@echo ""
	@docker run --rm -p 8080:8080 solid-ml-ssr-server || stty sane

# Build full SSR client
example-full-ssr-client:
	@echo "Building full SSR client..."
	@$(DUNE) build @examples/full_ssr_app/client/melange
	@mkdir -p examples/full_ssr_app/static
	@echo "Bundling with esbuild..."
	@npx esbuild _build/default/examples/full_ssr_app/client/client_output/examples/full_ssr_app/client/client.js --bundle --minify --target=es2020 --outfile=examples/full_ssr_app/static/client.js --format=esm 2>/dev/null
	@echo "Client built: examples/full_ssr_app/static/client.js"

# Run full SSR example (server + client)
example-full-ssr: example-full-ssr-client
	@echo ""
	@echo "=== Starting Full SSR Example ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@$(DUNE) exec examples/full_ssr_app/server/server.exe || stty sane

# Build and run full SSR example via Docker
example-full-ssr-docker:
	@echo "=== Building Docker image: solid-ml-full-ssr ==="
	@docker build -t solid-ml-full-ssr -f examples/full_ssr_app/Dockerfile .
	@echo ""
	@echo "=== Running container ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop (container will be removed)"
	@echo ""
	@docker run --rm -p 8080:8080 solid-ml-full-ssr || stty sane

# Build SSR API client
example-ssr-api-client:
	@echo "Building SSR API client..."
	@$(DUNE) build @examples/ssr_api_app/client/melange
	@mkdir -p examples/ssr_api_app/static
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/ssr_api_app/client/output && \
		npx esbuild examples/ssr_api_app/client/client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/ssr_api_app/static/client.js --format=esm 2>/dev/null
	@echo "Client built: examples/ssr_api_app/static/client.js"

# Run SSR API example (server + client with REST API fetching)
example-ssr-api: example-ssr-api-docker

# Run SSR API example locally (requires dream/cohttp/yojson installed)
example-ssr-api-local: example-ssr-api-client
	@echo ""
	@echo "=== Starting SSR API Example (local) ==="
	@echo "Visit http://localhost:$(PORT)"
	@echo "This app fetches data from JSONPlaceholder API"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@ENABLE_SSR_API_APP=true PORT=$(PORT) $(DUNE) exec examples/ssr_api_app/server.exe || stty sane

# Run SSR API example via Docker
example-ssr-api-docker:
	@echo "=== Building Docker image: solid-ml-ssr-api ==="
	@docker build -t solid-ml-ssr-api -f examples/ssr_api_app/Dockerfile .
	@echo ""
	@echo "=== Running container ==="
	@echo "Visit http://localhost:$(PORT)"
	@echo "Press Ctrl+C to stop (container will be removed)"
	@echo ""
	@docker run --rm -p $(PORT):$(PORT) -e PORT=$(PORT) solid-ml-ssr-api || stty sane

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
	@$(DUNE) build @examples/browser_counter/melange
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
	@$(DUNE) build @examples/browser_router/melange
	@mkdir -p examples/browser_router/dist
	@rm -f examples/browser_router/dist/router_demo.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/browser_router/output && \
		npx esbuild examples/browser_router/router_demo.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_router/dist/router_demo.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_router/"

# Build template compiler example
example-template-counter:
	@echo "Building template compiler counter example..."
	@$(DUNE) build @examples/template_counter/melange
	@mkdir -p examples/template_counter/dist
	@rm -f examples/template_counter/dist/template_counter.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/template_counter/output/examples/template_counter && \
		npx esbuild client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/template_counter/dist/template_counter.js --format=esm 2>/dev/null
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/template_counter/"

# Build all browser examples
browser-examples: example-browser example-browser-router example-template-counter
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

# Run browser tests (Node.js only; no DOM)
browser-tests:
	@echo "Running browser tests (Node.js, no DOM)..."
	@$(DUNE) build @test_browser/melange
	@# Melange emits ES modules; tell Node to treat output (and runtime) as ESM.
	@printf '{ "type": "module" }\n' > _build/default/test_browser/output/package.json
	@for d in _build/default/test_browser/output/node_modules/*; do \
		if [ -d "$$d" ]; then printf '{ "type": "module" }\n' > "$$d/package.json"; fi; \
	done
	@node _build/default/test_browser/output/test_browser/test_reactive.js

# Run browser tests in a real headless browser (requires Chrome)
browser-tests-headless:
	@echo "Running browser DOM tests (headless Chrome)..."
	@# Guard against accidentally committing diff markers in the test file.
	@if grep -n '^[+][l][e][t][ ]' test_browser_dom/test_template_dom.ml >/dev/null; then \
		echo "Error: found leading '+' diff markers in test_browser_dom/test_template_dom.ml"; \
		grep -n '^[+][l][e][t][ ]' test_browser_dom/test_template_dom.ml | sed -n '1,5p'; \
		exit 1; \
	fi
	@$(DUNE) build @test_browser_dom/melange
	@npx --yes esbuild _build/default/test_browser_dom/output/test_browser_dom/test_template_dom.js --bundle --format=iife --target=es2020 --outfile=_build/default/test_browser_dom/test_template_dom_bundle.js
	@tmp_dom="$$(mktemp)"; tmp_err="$$(mktemp)"; tmp_png="$$(mktemp --suffix=.png)"; \
	  artifacts_dir="_build/default/test_browser_dom/artifacts"; \
	  mkdir -p "$$artifacts_dir"; \
	  timeout 30s google-chrome --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
	    --allow-file-access-from-files --disable-web-security --virtual-time-budget=5000 \
	    --window-size=1280,720 --screenshot="$$tmp_png" \
	    --dump-dom file://$(PWD)/test_browser_dom/runner.html \
	    1>"$$tmp_dom" 2>"$$tmp_err"; \
	  if rg -q 'data-test-result="PASS"' "$$tmp_dom"; then \
	    rm -f "$$tmp_dom" "$$tmp_err" "$$tmp_png"; \
	    exit 0; \
	  else \
	    fail_dom="$$artifacts_dir/last_fail_dump_dom.html"; \
	    fail_err="$$artifacts_dir/last_fail_chrome_stderr.log"; \
	    fail_png="$$artifacts_dir/last_fail_screenshot.png"; \
	    cp "$$tmp_dom" "$$fail_dom"; \
	    cp "$$tmp_err" "$$fail_err"; \
	    cp "$$tmp_png" "$$fail_png" || true; \
	    echo "\nHeadless DOM tests failed."; \
	    echo "Saved artifacts:"; \
	    echo "  $$fail_dom"; \
	    echo "  $$fail_err"; \
	    echo "  $$fail_png"; \
	    echo "\n--- test-result element ---"; \
	    rg -n 'test-result|data-test-result|data-test-error|data-test-stack' "$$tmp_dom" || true; \
	    echo "--- chrome stderr (first 50 lines) ---"; \
	    sed -n '1,50p' "$$tmp_err" || true; \
	    echo "--- dumped DOM (first 120 lines) ---"; \
	    sed -n '1,120p' "$$tmp_dom" || true; \
	    rm -f "$$tmp_dom" "$$tmp_err" "$$tmp_png"; \
	    exit 1; \
	  fi

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
	@echo "  make example-ssr-server - Run SSR server example (requires dream)"
	@echo "  make examples           - Run all native examples"
	@echo ""
	@echo "Full SSR (requires: dream + cohttp-lwt-unix, or Docker):"
	@echo "  make example-full-ssr            - SSR with counter and todos"
	@echo "  make example-full-ssr-docker      - SSR with counter and todos (via Docker)"
	@echo "  make example-ssr-server-docker     - Basic SSR server demo (via Docker)"
	@echo "  make example-ssr-hydration-docker - Docker SSR hydration demo"
	@echo ""
	@echo "Browser development (requires Node.js for esbuild):"
	@echo "  make serve               - Build and serve browser examples"
	@echo "  make browser-examples    - Build all browser examples"
	@echo "  make browser-tests       - Run browser tests (Node-only)"
	@echo "  make browser-tests-headless - Run browser DOM tests (headless Chrome)"

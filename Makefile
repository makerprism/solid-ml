# solid-ml Makefile
#
# NOTE: This project uses dune 3.20.2 installed at /usr/bin/dune.
# The dune-project uses (lang dune 3.17) for compatibility.
# We use a fixed path instead of relying on PATH to avoid issues with opam
# environments where different dune versions from different switches could be
# inadvertently picked up. This ensures consistent builds across development environments.
#
# Override with: make DUNE=/path/to/dune <target>

DUNE ?= /usr/bin/dune

# Quick start:
#   make example-counter    # Run counter example
#   make example-router     # Run router example
#   make test               # Run all tests

# ==============================================================================
# Development
# ==============================================================================

# Build all packages
build:
	@$(DUNE) build @check --force 2>/dev/null || $(DUNE) build

# Run all tests
test:
	@$(DUNE) runtest

# Clean all build artifacts
clean:
	@$(DUNE) clean

# ==============================================================================
# Native Examples
# ==============================================================================

example-parallel:
	@echo "=== Running OCaml 5 Domain Parallelism Demo ==="
	@$(DUNE) exec examples/parallel/parallel.exe

example-ssr-api-app:
	@echo "=== Running SSR API App Demo ==="
	@$(DUNE) exec examples/ssr_api_app/server.exe

# ==============================================================================
# Browser Examples (require Node.js for esbuild)
# ==============================================================================

# Build and serve browser examples
serve:
	@echo ""
	@echo "=== Serving Browser Examples ==="
	@echo "Open http://localhost:8000 in your browser"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@python3 -m http.server 8000 -d examples || stty sane

# Build all browser examples
browser-examples: example-browser example-browser-router example-browser-cleanup example-full-ssr-client
	@echo ""
	@echo "All browser examples built! Run 'make serve' to view them."

# Build browser counter example
example-browser:
	@echo "Building browser counter example..."
	@$(DUNE) build @examples/browser_counter/melange
	@mkdir -p examples/browser_counter/dist
	@rm -f examples/browser_counter/dist/counter.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/browser_counter/output/examples/browser_counter && \
		npx esbuild counter.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_counter/dist/counter.js --format=esm
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_counter/"

# Build browser router example
example-browser-router:
	@echo "Building browser router example..."
	@$(DUNE) build @examples/browser_router/melange
	@mkdir -p examples/browser_router/dist
	@rm -f examples/browser_router/dist/router_demo.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/browser_router/output/examples/browser_router && \
		npx esbuild router_demo.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/browser_router/dist/router_demo.js --format=esm
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/browser_router/"

# Build browser router SSR server
example-browser-router-server:
	@echo "Building browser router SSR server..."
	@$(DUNE) build examples/browser_router/server.exe
	@echo ""
	@echo "Server built: examples/browser_router/server.exe"

# Run browser router SSR server
run-browser-router-server: example-browser-router example-browser-router-server
	@echo ""
	@echo "=== Starting Browser Router SSR Server ==="
	@echo "Visit http://localhost:8080/browser_router"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@$(DUNE) exec examples/browser_router/server.exe

# Build cleanup example
example-browser-cleanup:
	@echo "Building cleanup example..."
	@$(DUNE) build @examples/cleanup_example/melange
	@mkdir -p examples/cleanup_example/dist
	@rm -f examples/cleanup_example/dist/cleanup.js
	@echo "Bundling with esbuild..."
	@cd _build/default/examples/cleanup_example/output/examples/cleanup_example && \
		npx esbuild cleanup.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/cleanup_example/dist/cleanup.js --format=esm
	@echo ""
	@echo "Build complete! Run 'make serve' then open http://localhost:8000/cleanup_example/"

# Build full SSR client example
example-full-ssr-client:
	@echo "Building full SSR client..."
	@$(DUNE) build @examples/full_ssr_app/client/melange
	@mkdir -p examples/full_ssr_app/static
	@echo "Bundling with esbuild..."
	@npx esbuild _build/default/examples/full_ssr_app/client/client_output/examples/full_ssr_app/client/client.js --bundle --minify --target=es2020 --outfile=$(PWD)/examples/full_ssr_app/static/client.js --format=esm
	@echo ""
	@echo "Client built: examples/full_ssr_app/static/client.js"

# Build full SSR server example
example-full-ssr-server:
	@echo "Building full SSR server..."
	@$(DUNE) build examples/full_ssr_app/server/server.exe
	@echo ""
	@echo "Server built: examples/full_ssr_app/server/server.exe"

# ==============================================================================
# Full SSR (requires: dream + cohttp-lwt-unix, or Docker)
# ==============================================================================

# Build full SSR example
example-full-ssr: example-full-ssr-client example-full-ssr-server
	@echo ""
	@echo "Full SSR build complete."
	@echo "Run 'make run-full-ssr-server' to start the server."
	@echo "Visit http://localhost:8080"
	@echo ""

# Run full SSR server
PORT ?= 8080

run-full-ssr-server: example-full-ssr
	@echo ""
	@echo "=== Starting Full SSR Server ==="
	@echo "Visit http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@PORT=$(PORT) $(DUNE) exec examples/full_ssr_app/server/server.exe

# ==============================================================================
# Browser Tests
# ==============================================================================

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
	@CHROME_BIN=$${CHROME_BIN:-google-chrome}; \
	if ! command -v "$$CHROME_BIN" >/dev/null; then \
		echo "Error: Chrome executable not found. Set CHROME_BIN=/path/to/chrome"; \
		exit 1; \
	fi
	@if grep -n '^[+][l][e][t][ ]' test_browser_dom/test_template_dom.ml >/dev/null; then \
		echo "Error: found leading '+' diff markers in test_browser_dom/test_template_dom.ml"; \
		grep -n '^[+][l][e][t][ ]' test_browser_dom/test_template_dom.ml | sed -n '1,5p'; \
		exit 1; \
	fi
	@$(DUNE) build @test_browser_dom/melange
	@NODE_NO_WARNINGS=1 npx --yes esbuild _build/default/test_browser_dom/output/test_browser_dom/test_template_dom.js --bundle --format=iife --target=es2020 --outfile=_build/default/test_browser_dom/test_template_dom_bundle.js
	@tmp_dom="$$(mktemp)"; tmp_err="$$(mktemp)"; tmp_png="$$(mktemp --suffix=.png)"; \
	  artifacts_dir="_build/default/test_browser_dom/artifacts"; \
	  mkdir -p "$$artifacts_dir"; \
	  timeout 30s "$(CHROME_BIN)" --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
	    --allow-file-access-from-files --disable-web-security --virtual-time-budget=5000 \
	    --window-size=1280,720 --screenshot="$$tmp_png" \
	    --dump-dom file://$(PWD)/test_browser_dom/runner.html \
	    1>"$$tmp_dom" 2>"$$tmp_err"; \
	  if rg -q 'data-test-result="PASS"' "$$tmp_dom"; then \
	    echo "Headless DOM tests passed."; \
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
	@echo " make build              - Build all packages"
	@echo " make test               - Run all tests"
	@echo " make clean              - Remove build artifacts"
	@echo ""
	@echo "Examples:"
	@echo " make example-parallel  - Run OCaml 5 domain parallelism demo"
	@echo " make example-ssr-api-app - Run SSR API app demo"
	@echo ""
	@echo "Browser development (requires Node.js for esbuild):"
	@echo " make serve               - Build and serve browser examples"
	@echo " make browser-examples    - Build all browser examples"
	@echo ""
	@echo "Full SSR (requires dream + cohttp-lwt-unix, or Docker):"
	@echo " make example-full-ssr     - SSR with counter and todos"
	@echo ""
	@echo "Browser tests (requires Chrome):"
	@echo " make browser-tests       - Run browser tests (Node-only)"
	@echo " make browser-tests-headless - Run browser DOM tests (headless Chrome)"
	@echo ""
	@echo "Installation:"
	@echo "  opam install solid-ml solid-ml-ssr solid-ml-router"

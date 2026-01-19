Build:
  dune build examples/template_counter/ssr.exe
  dune build @examples/template_counter/melange

Run SSR:
  dune exec examples/template_counter/ssr.exe

Run browser demo:
  # bundle JS
  npx esbuild _build/default/examples/template_counter/output/examples/template_counter/client.js \
    --bundle --minify --target=es2020 --format=esm \
    --outfile=examples/template_counter/dist/template_counter.js

  # serve examples
  python3 -m http.server 8000 -d examples
  open http://localhost:8000/template_counter/

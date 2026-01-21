FROM debian:bookworm-slim AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        git \
        pkg-config \
        libev-dev \
        libgmp-dev \
        m4 \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

ENV DUNE_VERSION=3.20.2
RUN curl -fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v3/install.sh \
    | sh -s -- ${DUNE_VERSION} --install-root /usr --no-update-shell-config

WORKDIR /app
COPY . .

RUN ENABLE_SSR_API_APP=true dune build @examples/ssr_api_app/client/melange
RUN mkdir -p examples/ssr_api_app/static
RUN cd _build/default/examples/ssr_api_app/client/output && \
    npx esbuild examples/ssr_api_app/client/client.js --bundle --minify --target=es2020 \
    --outfile=/app/examples/ssr_api_app/static/client.js --format=esm 2>/dev/null

RUN ENABLE_SSR_API_APP=true dune build examples/ssr_api_app/server.exe

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends libev4 libgmp10 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/_build/default/examples/ssr_api_app/server.exe ./server.exe
COPY --from=build /app/examples/ssr_api_app/static ./static

ENV PORT=8080

EXPOSE 8080

CMD ["./server.exe"]

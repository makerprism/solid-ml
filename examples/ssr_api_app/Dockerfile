# Build stage: compile server (native) + client bundle (Melange)
FROM debian:bookworm-slim AS build

# Install system dependencies (compiler, headers, utilities)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        git \
        opam \
        pkg-config \
        libev-dev \
        libgmp-dev \
        libssl-dev \
        libcurl4-gnutls-dev \
        m4 \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

# NOTE: Opam usage is intentionally allowed here to install Melange.
SHELL ["/bin/bash", "-lc"]

ENV OPAMROOT=/opam
ENV OPAMYES=1
ENV OPAMJOBS=2

RUN opam init --disable-sandboxing --bare -y
RUN opam switch create 5.4.0 -y
RUN eval "$(opam env --switch=5.4.0)" && \
    opam install dune.3.21.0 melange mlx dream yojson curl

WORKDIR /app

COPY . .

# Build client bundle (Melange)
RUN opam exec --switch=5.4.0 -- dune build examples/ssr_api_app/client

# Build server (no enabled_if, always enabled)
RUN opam exec --switch=5.4.0 -- dune build examples/ssr_api_app/server/server.exe

# Bundle client.js with esbuild to resolve module imports
RUN cd _build/default/examples/ssr_api_app/client/output && \
    npx esbuild examples/ssr_api_app/client/client.js --bundle --minify --target=es2020 \
    --outfile=/app/examples/ssr_api_app/static/client.js --format=esm || \
    (echo "esbuild failed, copying unbundled client.js" && \
     find .. -name "client.js" -exec cp {} /app/examples/ssr_api_app/static/client.js \;)

# Runtime stage
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends libev4 libgmp10 libssl3 libcurl3-gnutls ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy server executable and static assets
COPY --from=build /app/_build/default/examples/ssr_api_app/server/server.exe ./server.exe
COPY --from=build /app/examples/ssr_api_app/static ./static

ENV PORT=8080
ENV STATIC_DIR=/app/static

EXPOSE 8080

CMD ["./server.exe"]

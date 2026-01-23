# Build stage: compile server (native) + client bundle (Melange)
FROM debian:bookworm-slim AS build

# Install system dependencies (compiler, headers, utilities)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        git \
        pkg-config \
        libev-dev \
        libgmp-dev \
        libcurl4-gnutls-dev \
        libssl-dev \
        m4 \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

# Install dune from official binary script
ENV DUNE_VERSION=3.20.2
RUN curl -fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v3/install.sh \
    | sh -s -- ${DUNE_VERSION} --install-root /usr --no-update-shell-config

WORKDIR /app
COPY . .

# Remove existing dune.lock so we can generate our own
RUN rm -rf dune.lock

# Generate dune.lock (downloads OCaml + all dependencies)
RUN dune pkg lock

# Build client bundle (Melange)
RUN dune build examples/full_ssr_app/client

# Build server (no enabled_if, always enabled)
RUN dune build examples/full_ssr_app/server/server.exe

# Copy generated client bundle into static directory for runtime stage
RUN cp _build/default/examples/full_ssr_app/client/client_output/examples/full_ssr_app/client/client.js \
       examples/full_ssr_app/static/client.js

# Copy entire client output including all generated JS files and node_modules
RUN cp -r _build/default/examples/full_ssr_app/client/client_output/* examples/full_ssr_app/static/

# Also copy Melange runtime files separately for cleaner path
RUN mkdir -p examples/full_ssr_app/static/melange.js && \
    find _build/default/examples/full_ssr_app/client/client_output -path "*/node_modules/melange.js/*.js" \
      -type f -exec cp {} examples/full_ssr_app/static/melange.js/ \;

# Runtime stage
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends libev4 libgmp10 libssl3 libcurl3-gnutls ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy server executable and static assets (preserve the path structure)
COPY --from=build /app/_build/default/examples/full_ssr_app/server/server.exe ./server.exe
RUN mkdir -p examples/full_ssr_app
COPY --from=build /app/examples/full_ssr_app/static ./examples/full_ssr_app/static

ENV PORT=8080
ENV STATIC_DIR=/app/static

EXPOSE 8080

CMD ["./server.exe"]

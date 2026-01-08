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
        m4 \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

# Install dune from official binary script (same approach as feedmansion)
ENV DUNE_VERSION=3.20.2
RUN curl -fsSL https://github.com/ocaml-dune/dune-bin-install/releases/download/v3/install.sh \
    | sh -s -- --install-root /usr --version ${DUNE_VERSION} --no-update-shell-config

WORKDIR /app
COPY . .

# Prepare dependencies using dune's package manager (no opam usage)
RUN dune pkg lock dream && dune pkg install

# Fetch melange binary release
ENV MELANGE_VERSION=4.0.0
RUN curl -L "https://github.com/melange-re/melange/releases/download/v${MELANGE_VERSION}/melange-${MELANGE_VERSION}-linux-x64.tar.gz" \
    | tar -xz -C /tmp \
    && mv /tmp/melange-${MELANGE_VERSION}-linux-x64 /usr/local/melange \
    && ln -sf /usr/local/melange/bin/melange /usr/local/bin/melange

ENV PATH="/usr/local/melange/bin:${PATH}"

# Build client bundle (Melange) and native server
RUN dune build examples/ssr_hydration_docker/client
RUN dune build examples/ssr_hydration_docker/server/server.exe

# Copy generated client bundle into static directory for runtime stage
RUN cp _build/default/examples/ssr_hydration_docker/client/client_output/examples/ssr_hydration_docker/client/client.js \
       examples/ssr_hydration_docker/static/client.js

# Runtime stage
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends libev4 libgmp10 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy server executable and static assets
COPY --from=build /app/_build/default/examples/ssr_hydration_docker/server/server.exe ./server.exe
COPY --from=build /app/examples/ssr_hydration_docker/static ./static

ENV PORT=8080
ENV STATIC_DIR=/app/static

EXPOSE 8080

CMD ["./server.exe"]

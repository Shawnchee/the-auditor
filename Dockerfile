# PR Auditor – Multi-stage Docker Build

# build Aderyn from source
FROM rust:1.82-slim-bookworm AS aderyn-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

RUN cargo install aderyn --locked

# Runtime image
FROM python:3.12-slim-bookworm AS runtime

LABEL maintainer="Shawnchee"
LABEL org.opencontainers.image.title="PR Auditor"
LABEL org.opencontainers.image.description="smart contract auditor workflow"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Slither (Solidity static analyzer)
RUN pip install --no-cache-dir slither-analyzer solc-select

# Install solc (Solidity compiler) – latest stable
RUN solc-select install 0.8.28 && solc-select use 0.8.28

# Install cargo-audit for Move / Rust smart contracts
COPY --from=rust:1.82-slim-bookworm /usr/local/cargo/bin/rustup /usr/local/bin/rustup
COPY --from=rust:1.82-slim-bookworm /usr/local/rustup /usr/local/rustup
COPY --from=rust:1.82-slim-bookworm /usr/local/cargo /usr/local/cargo
ENV PATH="/usr/local/cargo/bin:${PATH}"
ENV RUSTUP_HOME="/usr/local/rustup"
ENV CARGO_HOME="/usr/local/cargo"

RUN cargo install cargo-audit --locked

# Copy Aderyn binary from builder stage
COPY --from=aderyn-builder /usr/local/cargo/bin/aderyn /usr/local/bin/aderyn

# Copy action scripts
COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/

RUN chmod +x /entrypoint.sh /scripts/*.sh

ENTRYPOINT ["/entrypoint.sh"]

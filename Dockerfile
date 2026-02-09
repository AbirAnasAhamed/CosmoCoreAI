# Build Stage
FROM rust:1.80-slim-bookworm AS builder

WORKDIR /usr/src/app

# Copy manifests to cache dependencies
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release

# Cleaning up the artifacts from the dummy build
RUN rm -rf src

# Copy the actual source code
COPY . .

# Build the actual application
# We need to touch the main.rs file to trigger a rebuild
RUN touch src/main.rs
RUN cargo build --release

# Runtime Stage
FROM debian:bookworm-slim

# Install necessary runtime dependencies (e.g., for SSL/TLS if needed)
RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/bin

# Copy the binary from the builder stage
COPY --from=builder /usr/src/app/target/release/cosmocore_ai .

# Expose the application port
EXPOSE 8000

# Set the entrypoint
CMD ["./cosmocore_ai"]

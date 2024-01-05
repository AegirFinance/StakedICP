# TODO: Can we use 22.04? latest LTS?
FROM ubuntu:20.04

ENV IN_DOCKER=true

ENV NVM_DIR=/root/.nvm
ENV NVM_VERSION=v0.39.1
ENV NODE_VERSION=17.3.0
ENV VESSEL_VERSION=v0.6.4

ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV RUST_VERSION=1.72.1

ENV DFX_VERSION=0.15.2

# Install a basic environment needed for our build tools
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
RUN apt-get -y update && \
    apt-get -y install --no-install-recommends curl ca-certificates \
      build-essential pkg-config libssl-dev llvm-dev liblmdb-dev clang cmake \
      rsync reprotest disorderfs faketime rsync sudo wabt


# Install Node.js using nvm
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"
RUN curl --fail -sSf https://raw.githubusercontent.com/creationix/nvm/${NVM_VERSION}/install.sh | bash
RUN . "${NVM_DIR}/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "${NVM_DIR}/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "${NVM_DIR}/nvm.sh" && nvm alias default v${NODE_VERSION}

# Install Rust and Cargo
ENV PATH=/opt/cargo/bin:${PATH}
RUN curl --fail https://sh.rustup.rs -sSf \
        | sh -s -- -y --default-toolchain ${RUST_VERSION}-x86_64-unknown-linux-gnu --no-modify-path && \
    rustup default ${RUST_VERSION}-x86_64-unknown-linux-gnu && \
    rustup target add wasm32-unknown-unknown &&\
    cargo install ic-wasm

# Install dfx
RUN sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"

# Install vessel
RUN curl --fail -sSL https://github.com/dfinity/vessel/releases/download/${VESSEL_VERSION}/vessel-linux64 > /usr/local/bin/vessel && chmod a+x /usr/local/bin/vessel

RUN mkdir /canister
WORKDIR /canister

# Fetch rust deps
COPY Cargo.toml Cargo.lock .
RUN mkdir -p ./cmd/oracle/ ./src/signing
COPY cmd/oracle/Cargo.toml cmd/oracle/Cargo.lock ./cmd/oracle/.
COPY src/signing/Cargo.toml ./src/signing/.
RUN cargo fetch --locked --target wasm32-unknown-unknown

# Install npm dependencies
COPY package.json package-lock.json .
RUN npm ci

# Add the rest of the source files
ADD . .

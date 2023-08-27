#!/bin/bash

set -ex

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        lsb-release \
        wget && \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null && \
    apt-get update -y -qq --fix-missing && \
    apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        clang-11 \
        gcc \
        git \
        jq \
        libssl-dev \
        llvm-11 \
        make \
        ruby \
        postgresql-server-dev-15 \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*


wget -qO- https://sh.rustup.rs | RUSTUP_HOME=$PGHOME/.rustup CARGO_HOME=$PGHOME/.cargo sh -s -- -y --profile minimal --default-toolchain=1.70.0


export PATH="$PATH:$PGHOME/.cargo/bin"
export CARGO_INSTALL_ROOT=$PGHOME/.cargo
export RUSTUP_HOME=$PGHOME/.rustup
export CARGO_HOME=$PGHOME/.cargo

rustup default 1.70.0

export PLRUST=$PGHOME/.plrust
git clone --depth 1 --branch v1.2.3 https://github.com/tcdi/plrust.git $PLRUST

cd $PLRUST

PGRX_VERSION=$(cargo metadata --format-version 1 | jq -r '.packages[]|select(.name=="pgrx")|.version') && \
    cargo install cargo-pgrx --force --version "$PGRX_VERSION" && \
    rustup component add llvm-tools-preview rustc-dev && \
    cd $PLRUST/plrustc && ./build.sh && cp ../build/bin/plrustc $PGHOME/.cargo/bin && \
    cargo pgrx init --pg15 $(which pg_config) && \
    cd $PLRUST/plrust && STD_TARGETS="$(uname -m)-postgres-linux-gnu" ./build && \
    cargo pgrx install --release --features trusted && \
    cd $PLRUST && find . -type d -name target | xargs rm -r && \
    rustup component remove llvm-tools-preview rustc-dev

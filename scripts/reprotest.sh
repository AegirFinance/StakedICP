#!/bin/bash

# reprotest.sh runs a build-reproducibility test as described in
# https://internetcomputer.org/docs/current/developer-docs/backend/reproducible-builds/#testing-reproducibility

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

set -e

ROOT="$DIR/.."
cd "$ROOT"

export DFX_NETWORK="${1:-local}"
if [ -n "$1" ]; then
  shift
fi
CANISTER="$@"
if [ -z "$CANISTER" ]; then
  CANISTER="--all"
fi

if [ -z "$IN_DOCKER" ]; then
  # Bootstrap ourselves into the docker image
  docker build -t stakedicp --platform amd64 .
  docker run --rm --privileged -ti -v "$ROOT:/canister" stakedicp bash -c "./scripts/reprotest.sh"
  exit $?
fi

# We're already in docker, so carry on with the build

echo "Network:            $DFX_NETWORK"
echo "Canister:           $CANISTER"

echo
echo == npm ci
echo

npm ci

echo
echo == dfx build
echo

mkdir artifacts
reprotest -vv --store-dir=artifacts --variations "+all,-time" "dfx build --network=$DFX_NETWORK $CANISTER" ".dfx/ic/canisters/*/*.wasm"

#!/bin/bash

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
  docker build -t stakedicp .
  docker run --rm -ti -v "$ROOT:/canister" stakedicp bash -c "./scripts/build.sh"
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

dfx build --network="$DFX_NETWORK" $CANISTER

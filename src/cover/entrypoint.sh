#!/bin/bash -e

CANISTER="$1"
if [ -z "$CANISTER" ]; then
    >&2 echo "usage: ./entrypoint.sh CANISTER_NAME"
    exit 1
fi

dfx build --network ic "${CANISTER}" >&2 
ic-cdk-optimizer \
    ".dfx/ic/canisters/${CANISTER}/${CANISTER}.wasm" \
    -o ".dfx/ic/canisters/${CANISTER}/${CANISTER}.wasm" >&2 

openssl dgst -sha256 ".dfx/ic/canisters/${CANISTER}/${CANISTER}.wasm" | \
    awk '/.+$/{print "0x"$2}' | \
    tee ".dfx/ic/canisters/${CANISTER}/${CANISTER}.hash"

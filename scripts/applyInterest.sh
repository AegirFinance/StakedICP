#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

set -e

NETWORK="${1:-local}"
AMOUNT="${2}"
TIMESTAMP="${3}"

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    NEURON_ACCOUNT_ID="d0c352c04c8bfd4cf6cf827903a1483253bee4e354b8361b5b7023b72d384007"
    NEURON_ID="16_136_654_443_876_485_299"
    ;;

  "local")
    DFX_OPTS=""
    NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"
    NEURON_ID="$(existing_neuron_id 1)"
    ;;

  *)
    echo "unknown network: $NETWORK" >&2
    exit 1
    ;;
esac

if [ -z "$NEURON_ID" ]; then
  >&2 echo "Neuron not found"
  exit 1
fi

echo "Network:           $NETWORK"
echo "Amount (e8s):      ${AMOUNT:-all}"
echo "Timestamp:         ${TIMESTAMP:-now}"
echo "Staking Neuron ID: $NEURON_ID"

canister() {
  dfx canister $DFX_OPTS "$@"
}

if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP="null"
else
    TIMESTAMP="opt $(($TIMESTAMP * 1000000000))"
fi

if [ -z "$AMOUNT" ]; then
    canister call deposits applyInterestFromNeuron "(${TIMESTAMP}: opt int)"
else
    canister call deposits applyInterest "(${AMOUNT}: nat64, ${TIMESTAMP}: opt int)"
fi

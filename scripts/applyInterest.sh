#!/usr/bin/env bash

set -e

NETWORK="${1:-local}"
AMOUNT="${2}"
TIMESTAMP="${3}"

if [ -z "${AMOUNT}" ]; then
    <&2 echo "usage: ./scripts/applyInterest.sh NETWORK AMOUNT_E8S [EPOCH_SEC]"
    exit 1
fi

# epoch nanoseconds


existing_neuron_id() {
  (dfx canister call governance \
    list_neurons \
    '(record { neuron_ids = vec {}; include_neurons_readable_by_caller = true})' \
    | grep -o "id = [0-9_]\+" \
    | grep -o "[0-9_]\+") \
}

make_neuron() {
  local NEURON_ACCOUNT_ID="$1"
  local NEURON_MEMO="$2"
  # Create a neuron
  (
    dfx ledger transfer "$NEURON_ACCOUNT_ID" --memo "$NEURON_MEMO" --amount "1.00"
    dfx canister call governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })"
  ) > 2
  existing_neuron_id
}

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    NEURON_ACCOUNT_ID="d0c352c04c8bfd4cf6cf827903a1483253bee4e354b8361b5b7023b72d384007"
    NEURON_ID="16_136_654_443_876_485_299"
    ;;

  "local")
    DFX_OPTS=""
    NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"
    NEURON_ID="$(existing_neuron_id || make_neuron "$NEURON_ACCOUNT_ID" "5577006791947779410")"
    ;;

  *)
    echo "unknown network: $NETWORK" >2
    exit 1
    ;;
esac

echo "Network:           $NETWORK"
echo "Amount (e8s):      $AMOUNT"
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

canister call deposits applyInterest "(${AMOUNT}: nat64, ${TIMESTAMP}: opt int)"

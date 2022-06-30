#!/usr/bin/env bash

export IC_VERSION=dd3a710b03bd3ae10368a91b255571d012d1ec2f

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

existing_neuron_id() {
  local INDEX="${1:-1}"
  (dfx canister call governance \
    list_neurons \
    '(record { neuron_ids = vec {}; include_neurons_readable_by_caller = true})' \
    | grep -o "id = [0-9_]\+" \
    | awk "NR == ${INDEX}" \
    | grep -o "[0-9_]\+")
}

make_neuron() {
  local INDEX="$1"
  local NEURON_ACCOUNT_ID="$2"
  local NEURON_MEMO="$3"
  # Create a neuron
  (
    echo "Transfer 1 ICP to $NEURON_ACCOUNT_ID, memo: $NEURON_MEMO"
    dfx ledger transfer "$NEURON_ACCOUNT_ID" --memo "$NEURON_MEMO" --amount "1.00"
    echo "Claim neuron by memo: $NEURON_MEMO"
    dfx canister call governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })"

    # Add the deposits canister as a hotkey
    echo "Add hot key to neuron"
    "$DIR/addHotKey.sh" local "$(existing_neuron_id $INDEX)"
  ) >&2
  existing_neuron_id $INDEX
}

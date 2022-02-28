#!/usr/bin/env bash

set -e

MODE="${1:-install}"

canister_exists() {
  (dfx canister status "$1" 2>&1 | grep 'Module hash: 0x')
}

echo
echo == Dependencies.
echo

vessel install

echo
echo == Create.
echo

# Created in specific order so that the canister ids always match
dfx canister create governance
dfx canister create ledger
dfx canister create --all

GOVERNANCE_CANISTER_ID="$(dfx canister id governance)"
if [[ "$GOVERNANCE_CANISTER_ID" != "rrkah-fqaaa-aaaaa-aaaaq-cai" ]]; then
  echo "Unexpected governance canister id: $GOVERNANCE_CANISTER_ID" >&2
  exit 1
fi

LEDGER_CANISTER_ID="$(dfx canister id ledger)"
if [[ "$LEDGER_CANISTER_ID" != "ryjl3-tyaaa-aaaaa-aaaba-cai" ]]; then
  echo "Unexpected ledger canister id: $LEDGER_CANISTER_ID" >&2
  exit 1
fi

echo
echo == Install Ledger
echo

(canister_exists ledger) || (
  ln -sf ledger.private.did src/ledger/ledger.did

  CURRENT_ACC=$(dfx identity whoami)

  dfx identity use minter || (dfx identity new minter && dfx identity use minter)
  export MINT_ACC=$(dfx ledger account-id)

  dfx identity use "$CURRENT_ACC"
  export LEDGER_ACC=$(dfx ledger account-id)

  dfx deploy ledger --argument '(record {minting_account = "'${MINT_ACC}'"; initial_values = vec { record { "'${LEDGER_ACC}'"; record { e8s=100_000_000_000 } }; }; send_whitelist = vec {}})'

  ln -sf ledger.public.did src/ledger/ledger.did
)

echo
echo == Install Governance
echo

(canister_exists governance) || (
  MSG="$(cat src/governance/initial-governance.hex)"
  dfx deploy governance --argument-type raw --argument "$MSG"
)

echo
echo == Build.
echo

dfx build

echo
echo == Install.
echo

dfx canister install ledger_candid --mode="$MODE"

LOGO="data:image/jpeg;base64,$(base64 -w0 logo.png)"
dfx canister install token --mode="$MODE" --argument "$(cat << EOM
("${LOGO}", "Staked ICP", "stICP", 8, 100_000_000, principal "$(dfx canister id deposits)", 10_000)
EOM
)"

NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"
NEURON_MEMO="5577006791947779410"

existing_neuron_id() {
  (dfx canister call governance \
	  list_neurons \
	  '(record { neuron_ids = vec {}; include_neurons_readable_by_caller = true})' \
	  | grep -o "id = [0-9_]\+" \
	  | grep -o "[0-9_]\+") \
	  || echo ""
}

if [ -z "$(existing_neuron_id)" ]; then
  # Create a neuron
  dfx ledger transfer "$NEURON_ACCOUNT_ID" --memo "$NEURON_MEMO" --amount "1.00"
  dfx canister call governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })"
fi

NEURON_ID="$(existing_neuron_id)"
echo "staking neuron id: $NEURON_ID"

dfx canister install deposits --mode="$MODE" --argument "$(cat << EOM
(record {
  governance             = principal "$(dfx canister id governance)";
  ledger                 = principal "$(dfx canister id ledger)";
  ledgerCandid           = principal "$(dfx canister id ledger_candid)";
  token                  = principal "$(dfx canister id token)";
  owners                 = vec { principal "$(dfx identity get-principal)" };
  stakingNeuronId        = record { id = ${NEURON_ID} : nat64 };
  stakingNeuronAccountId = "${NEURON_ACCOUNT_ID}";
})
EOM
)"

echo
echo == Deploy.
echo

npm start

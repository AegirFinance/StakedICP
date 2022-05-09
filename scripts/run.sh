#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

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
echo == Deploy
echo

./scripts/deploy.sh "local" "$MODE"

echo
echo == Initial Data
echo

dfx canister call deposits applyInterest "(58000: nat64, null)"

echo
echo == Serve Website
echo

npm run start

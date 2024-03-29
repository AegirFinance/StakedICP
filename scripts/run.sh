#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

set -e

MODE="${1:-install}"

canister_exists() {
  (dfx canister info "$1" 2>&1 | grep 'Module hash: 0x')
}

echo
echo == Dependencies.
echo

vessel install

echo
echo == Create Minting Account.
echo

if (dfx identity list | grep minter 2>&1 >/dev/null) ; then
    echo "minter account already exists" >&2
else
    dfx identity import minter <(cat <<EOF
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEICJxApEbuZznKFpV+VKACRK30i6+7u5Z13/DOl18cIC+oAcGBSuBBAAK
oUQDQgAEPas6Iag4TUx+Uop+3NhE6s3FlayFtbwdhRVjvOar0kPTfE/N8N6btRnd
74ly5xXEBNSXiENyxhEuzOZrIWMCNQ==
-----END EC PRIVATE KEY-----
EOF
    )
fi

dfx identity use minter

echo
echo == Install NNS.
echo

# Created in specific order so that the canister ids always match
if canister_exists "nns-governance"; then
    echo "nns-governance already exists skipping nns install" >&2
else
    dfx extension install nns || true
    dfx nns --identity minter install
    dfx ledger transfer --identity minter --memo 0 --amount 10000 $(dfx ledger account-id)
fi

echo
echo == Create Canisters.
echo

dfx canister create --all

echo
echo == Deploy
echo

./scripts/deploy.sh "local" "$MODE"

echo
echo == Initial Data
echo

dfx canister call deposits setSchedulerPaused '(false)'
dfx canister call deposits refreshNeuronsAndApplyInterest

echo
echo == Serve Website
echo

npm run start

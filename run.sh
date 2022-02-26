#!/usr/bin/env bash

set -e

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
echo == Install Governance
echo

echo Skipping.
# TODO: Fix this. Disabled for now..
# (dfx canister status governance 2>&1 | grep 'Status: Running') || (
# read -r -d '' MSG << EOM
# (
#   record {
#       default_followees = vec {};
#       wait_for_quiet_threshold_seconds = 300 : nat64;
#       metrics = null;
#       node_providers = vec {};
#       economics = opt record {
#         max_proposals_to_keep_per_topic = 100 : nat32;
#         maximum_node_provider_rewards_e8s = 1 : nat64;
#         minimum_icp_xdr_rate = 100 : nat64;
#         neuron_management_fee_per_proposal_e8s = 1_000_000 : nat64;
#         neuron_minimum_stake_e8s = 100_000_000 : nat64;
#         neuron_spawn_dissolve_delay_seconds = 604_800 : nat64;
#         reject_cost_e8s = 100_000_000 : nat64;
#         transaction_fee_e8s = 10_000 : nat64;
#       };
#       latest_reward_event = null;
#       to_claim_transfers = vec {};
#       short_voting_period_seconds = 60 : nat64;
#       proposals = vec {};
#       in_flight_commands = vec {};
#       neurons = vec {};
#       genesis_timestamp_seconds = 0 : nat64;
#   },
# )
# EOM

#   dfx deploy governance --argument "$MSG"
# )

echo
echo == Install Ledger
echo

(dfx canister status ledger 2>&1 | grep 'Status: Running') || (
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
echo == Build.
echo

dfx build

echo
echo == Install.
echo

dfx canister install ledger_candid --mode=reinstall

LOGO="data:image/jpeg;base64,$(base64 -w0 logo.png)"
dfx canister install token --mode=reinstall --argument "$(cat << EOM
("${LOGO}", "Staked ICP", "stICP", 8, 100_000_000, principal "$(dfx canister id deposits)", 10_000)
EOM
)"

NEURON_ID="0" # TODO: Create a neuron
NEURON_ACCOUNTID="$(dfx ledger account-id)" # TODO: Create a neuron
dfx canister install deposits --mode=reinstall --argument "$(cat << EOM
(record {
  governance             = principal "$(dfx canister id governance)";
  ledger                 = principal "$(dfx canister id ledger)";
  ledgerCandid           = principal "$(dfx canister id ledger_candid)";
  token                  = principal "$(dfx canister id token)";
  owners                 = vec { principal "$(dfx identity get-principal)" };
  stakingNeuronId        = record { id = ${NEURON_ID} : nat64 };
  stakingNeuronAccountId = "${NEURON_ACCOUNTID}";
})
EOM
)"

echo
echo == Deploy.
echo

npm start

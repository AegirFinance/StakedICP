#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

NETWORK="$1"
PROPOSAL_ID="$2"

if [ -z "$NETWORK" ]; then
  echo "usage: ./listProposals.sh NETWORK [PROPOSAL_ID]" >&2
  exit 1
fi

if [ -n "$PROPOSAL_ID" ]; then
    dfx canister --network "$NETWORK" call governance get_proposal_info "($PROPOSAL_ID)"
else
    read -r -d '' MSG << EOM
    (record {
        include_reward_status = vec {};
        before_proposal = null;
        limit = 100;
        exclude_topic = vec {};
        include_status = vec {};
    })
EOM

    dfx canister --network "$NETWORK" call governance list_proposals "$MSG"
fi

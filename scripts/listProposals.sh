#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

NETWORK="$1"
PROPOSAL_ID="$2"

if [ -z "$NETWORK" ]; then
  echo "usage: ./listProposals.sh NETWORK [PROPOSAL_ID]" >&2
  exit 1
fi

ID_FIELD="null"
LIMIT="100"
if [ -n "$PROPOSAL_ID" ]; then
    ID_FIELD="opt record { id = $(($PROPOSAL_ID + 1)) : nat64 }"
    LIMIT="1"
fi

read -r -d '' MSG << EOM
(record {
    include_reward_status = vec {};
    before_proposal = ${ID_FIELD};
    limit = ${LIMIT};
    exclude_topic = vec {};
    include_status = vec {};
})
EOM

dfx canister --network "$NETWORK" call governance list_proposals "$MSG"

#!/bin/bash

OUT="$1"
if [ -z "$OUT" ]; then
    echo "usage: ./snapshot.sh OUTPUT_DIR"
    exit 1
fi

echo token.getHolders
dfx canister --network ic call token getHolders '(0, 1024)' > "$OUT/token.getHolders.did"

for method in getAppliedInterest proposalNeuron stakingNeurons aprMicrobips getReferralData; do
    echo deposits.$method
    dfx canister --network ic call deposits "$method" > "$OUT/deposits.$method.did"
done

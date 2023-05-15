#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NETWORK=${1:-local}

case "$NETWORK" in
    "ic")
        IC_URL="https://icp0.io"
        ;;

    "local")
        IC_URL="http://localhost:$(dfx info replica-port)"
        ;;

    *)
        echo "unknown network: $NETWORK" >&2
        exit 1
        ;;
esac

canister() {
    dfx canister --network $NETWORK "$@"
}

echo Build oracle
cargo build -p oracle

echo Get the signing canister address
SIGNING_ADDRESS="$(canister call signing address | tr -d ')("')"
echo Address: "$SIGNING_ADDRESS"

echo Check initial balance
LOCAL_BALANCE="$(dfx ledger --network $NETWORK balance)"
if [[ "$(echo $LOCAL_BALANCE | cut -d\. -f1)" == "0" ]]; then
    echo Insufficient Initial Balance: $LOCAL_BALANCE, Ensure the "$(dfx identity whoami)" account has 17 ICP
    exit 1
fi
echo Initial Balance: $LOCAL_BALANCE

echo Exporting identity
IDENTITY_PEM="$(mktemp)"
dfx identity export "$(dfx identity whoami)" > "$IDENTITY_PEM"
echo pem: $IDENTITY_PEM

echo Creating new neurons
make_neuron() {
    "$DIR/../target/debug/oracle" make-neuron \
        --private-pem "$IDENTITY_PEM" \
        --deposits-canister $(canister id deposits) \
        --signing-canister $(canister id signing) \
        --governance $(canister id nns-governance) \
        --icp-ledger $(canister id nns-ledger) \
        --ic-url "$IC_URL" \
        --delay "$1"
}

mkdir -p "$DIR/../.dfx/$NETWORK"
OUT="$DIR/../.dfx/$NETWORK/neurons.did"
if ! test -f "$OUT" ; then
    <&2 echo "Creating $NETWORK neurons file: $OUT"
    NEW_NEURON_IDS=$(cat <<-EOM
    vec {
$(make_neuron "15778800");
$(make_neuron "31557600");
$(make_neuron "47336400");
$(make_neuron "63115200");
$(make_neuron "78894000");
$(make_neuron "94672800");
$(make_neuron "110451600");
$(make_neuron "126230400");
$(make_neuron "142009200");
$(make_neuron "157788000");
$(make_neuron "173566800");
$(make_neuron "189345600");
$(make_neuron "205124400");
$(make_neuron "220903200");
$(make_neuron "236682000");
$(make_neuron "252460800");
}
EOM
)
    echo "$NEW_NEURON_IDS" > "$OUT"
else
    NEW_NEURON_IDS=$(cat "$OUT")
fi


echo Reset the deposits canister
echo $ dfx canister --network $NETWORK call deposits resetStakingNeurons --argument-file "$OUT"

echo Check the remaining amount of needed ICP is in the deposits canister,
echo top it up based on the token totalSupply - 16, then flush the pending
echo deposits to rebalance neurons:
echo $ dfx canister --network $NETWORK deposits flushPendingDeposits

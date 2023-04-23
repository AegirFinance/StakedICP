#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NETWORK=local

case "$NETWORK" in
    "ic")
        IC_URL="https://ic0.app"
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

echo Check initial balance
SIGNING_BALANCE="$(dfx ledger balance "$SIGNING_ADDRESS")"
if [[ "$(echo $SIGNING_BALANCE | cut -d\. -f1)" == "0" ]]; then
    echo Insufficient Initial Balance: $SIGNING_BALANCE, Transfer ICP to $SIGNING_ADDRESS with:
    echo "  dfx ledger --network $NETWORK transfer --memo 0 --amount 17 \"$SIGNING_ADDRESS\""
    exit 1
fi
echo Initial Balance: $SIGNING_BALANCE

echo Creating new neurons
make_neuron() {
    "$DIR/../target/debug/oracle" make-neuron \
        --private-pem ~/.config/dfx/identity/default/identity.pem \
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
$(make_neuron "252460800");
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
}
EOM
)
    echo "$NEW_NEURON_IDS" > "$OUT"
else
    NEW_NEURON_IDS=$(cat "$OUT")
fi


echo Reset the deposits canister
canister call deposits resetStakingNeurons "(vec {$NEW_NEURON_IDS})"

echo Check the remaining amount of needed ICP is in the deposits canister

echo Flush pending deposits to rebalance neurons
canister deposits call flushPendingDeposits

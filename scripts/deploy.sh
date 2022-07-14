#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

set -e

NETWORK="${1:-local}"

MODE="${2:-install}"

CANISTER="${3}"

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    PROPOSAL_NEURON_ACCOUNT_ID="252fdf1003d53ee3fb03a7446a7836276e24078901a06da9dd1a0b1dd31a28bd"
    PROPOSAL_NEURON_ID="13_739_920_397_011_050_625"
    ORIGINAL_STAKING_NEURON_ACCOUNT_ID="d0c352c04c8bfd4cf6cf827903a1483253bee4e354b8361b5b7023b72d384007"
    ORIGINAL_STAKING_NEURON_ID="16_136_654_443_876_485_299"
    read -r -d '' STAKING_NEURONS << EOM
${ORIGINAL_STAKING_NEURON_ID}
EOM
    OWNERS='principal "b66ir-rprad-rut4a-acjje-naq3d-ymndg-itex7-47hrz-vvzqy-3le4a-eae"; principal "ckbyu-bzwwp-bxvwo-ewhjd-7ewsx-7wux3-c3foy-gp62f-enftx-nec3u-wqe"; principal "dtwfm-dtbib-y277g-oeali-iu4z4-m66x5-lofpb-oytcd-ursw2-2ne77-3qe"'
    export NODE_ENV=production

    if [[ "$MODE" == "reinstall" ]]; then
      echo "reinstall forbidden on network: $NETWORK" >&2
      exit 1
    fi
    ;;

  "local")
    DFX_OPTS=""
    local_neurons >/dev/null
    PROPOSAL_NEURON_ID="$(local_neuron 1)"
    ORIGINAL_STAKING_NEURON_ID="$(local_neuron 2)"
    STAKING_NEURONS="$(local_neurons | tail -n +2)"

    OWNERS="principal \"$(dfx identity get-principal)\""
    export NODE_ENV=development
    ;;

  *)
    echo "unknown network: $NETWORK" >&2
    exit 1
    ;;
esac

echo "Network:            $NETWORK"
echo "Mode:               $MODE"
echo "Proposal Neuron ID: $PROPOSAL_NEURON_ID"
echo -e "Staking Neuron IDs:\n$STAKING_NEURONS"
if [ -n "$CANISTER" ]; then
    echo "Canister:           $CANISTER"
fi

canister() {
  dfx canister $DFX_OPTS "$@"
}

canister_exists() {
  ($CANISTER status "$1" 2>&1 | grep 'Module hash: 0x')
}

echo
echo == Dependencies.
echo

vessel install

echo
echo == Build.
echo

dfx build --network "$NETWORK" $CANISTER

echo
echo == Optimize.
echo

optimize() {
    local f=".dfx/${NETWORK}/canisters/$1/$1.wasm"
    ic-cdk-optimizer "$f" -o "$f"
}

if [[ "$CANISTER" == "" ]]; then
    for c in token deposits metrics; do
        optimize "$c"
    done
else
    optimize "$CANISTER"
fi

if [[ "$CANISTER" == "" ]] || [[ "$CANISTER" == "token" ]]; then

echo
echo == Install token.
echo

LOGO="data:image/jpeg;base64,$(base64 -w0 src/website/public/logo.png)"
canister install token --mode="$MODE" --argument "$(cat << EOM
("${LOGO}", "Staked ICP", "stICP", 8, 100_000_000, principal "$(canister id deposits)", 10_000)
EOM
)"

fi


if [[ "$CANISTER" == "" ]] || [[ "$CANISTER" == "deposits" ]]; then

echo
echo == Install deposits.
echo

canister stop deposits

canister install deposits --mode="$MODE" --argument "$(cat << EOM
(record {
  governance             = principal "$(canister id governance)";
  ledger                 = principal "$(canister id ledger)";
  ledgerCandid           = principal "ockk2-xaaaa-aaaai-aaaua-cai";
  token                  = principal "$(canister id token)";
  owners                 = vec { $OWNERS };
  stakingNeuron          = opt record {
    id = record { id = ${ORIGINAL_STAKING_NEURON_ID} : nat64 };
    accountId = "${ORIGINAL_STAKING_NEURON_ACCOUNT_ID}";
  };
})
EOM
)"

canister start deposits

echo "Setting proposal neuron: $PROPOSAL_NEURON_ID"
canister call deposits setProposalNeuron "(${PROPOSAL_NEURON_ID} : nat64)"
for NEURON_ID in $STAKING_NEURONS; do
    echo "Adding staking neuron: $NEURON_ID"
    canister call deposits addStakingNeuron "(${NEURON_ID} : nat64)"
done

fi

if [[ "$CANISTER" == "" ]] || [[ "$CANISTER" == "metrics" ]]; then

echo
echo == Install metrics.
echo

canister install metrics --mode="$MODE" --argument "$(cat <<EOM
(record {
  deposits = principal "$(canister id deposits)";
  token    = principal "$(canister id token)";
  auth     = opt "$(echo -n $METRICS_AUTH | base64)";
})
EOM
)"

fi

if [[ "$CANISTER" == "" ]] || [[ "$CANISTER" == "website" ]]; then

if [[ "$NETWORK" != "local" ]]; then
  echo
  echo == Install website.
  echo

  canister install website --mode="$MODE"
fi

fi

if [[ "$NETWORK" == "local" ]]; then
  echo
  echo == Set staking neurons to follow proposal neuron.
  echo

  for NEURON_ID in $STAKING_NEURONS; do
    $DIR/followNeuron.sh local "$NEURON_ID" "$PROPOSAL_NEURON_ID"
  done
fi

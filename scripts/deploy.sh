#!/usr/bin/env bash

set -e

NETWORK="${1:-local}"

MODE="${2:-install}"

CANISTER="${3}"

existing_neuron_id() {
  (dfx canister call governance \
    list_neurons \
    '(record { neuron_ids = vec {}; include_neurons_readable_by_caller = true})' \
    | grep -o "id = [0-9_]\+" \
    | grep -o "[0-9_]\+") \
}

make_neuron() {
  local NEURON_ACCOUNT_ID="$1"
  local NEURON_MEMO="$2"
  # Create a neuron
  (
    dfx ledger transfer "$NEURON_ACCOUNT_ID" --memo "$NEURON_MEMO" --amount "1.00"
    dfx canister call governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })"
  ) > 2
  existing_neuron_id
}

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    NEURON_ACCOUNT_ID="d0c352c04c8bfd4cf6cf827903a1483253bee4e354b8361b5b7023b72d384007"
    NEURON_ID="16_136_654_443_876_485_299"
    OWNERS='principal "b66ir-rprad-rut4a-acjje-naq3d-ymndg-itex7-47hrz-vvzqy-3le4a-eae"; principal "ckbyu-bzwwp-bxvwo-ewhjd-7ewsx-7wux3-c3foy-gp62f-enftx-nec3u-wqe"; principal "dtwfm-dtbib-y277g-oeali-iu4z4-m66x5-lofpb-oytcd-ursw2-2ne77-3qe"'
    export NODE_ENV=production

    if [[ "$MODE" == "reinstall" ]]; then
      echo "reinstall forbidden on network: $NETWORK" >2
      exit 1
    fi
    ;;

  "local")
    DFX_OPTS=""
    NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"
    NEURON_ID="$(existing_neuron_id || make_neuron "$NEURON_ACCOUNT_ID" "5577006791947779410")"
    OWNERS="principal \"$(dfx identity get-principal)\""
    export NODE_ENV=development
    ;;

  *)
    echo "unknown network: $NETWORK" >2
    exit 1
    ;;
esac

echo "Network:           $NETWORK"
echo "Mode:              $MODE"
echo "Staking Neuron ID: $NEURON_ID"
if [ -n "$CANISTER" ]; then
    echo "Canister:          $CANISTER"
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

dfx build --network "$NETWORK"

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

canister install deposits --mode="$MODE" --argument "$(cat << EOM
(record {
  governance             = principal "$(canister id governance)";
  ledger                 = principal "$(canister id ledger)";
  ledgerCandid           = principal "$(canister id ledger_candid)";
  token                  = principal "$(canister id token)";
  owners                 = vec { $OWNERS };
  stakingNeuron          = opt record {
    id = record { id = ${NEURON_ID} : nat64 };
    accountId = "${NEURON_ACCOUNT_ID}";
  };
})
EOM
)"

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

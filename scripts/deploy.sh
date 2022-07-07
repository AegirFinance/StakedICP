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
    PROPOSAL_NEURON_ACCOUNT_ID="02231a0463394a9a040a4faac9e1fbe3bc5da96898d408ae7892ad98b8df7a7f"
    PROPOSAL_NEURON_ID="$(ensure_neuron 1 "$PROPOSAL_NEURON_ACCOUNT_ID" "1063793040729364723")"
    ORIGINAL_STAKING_NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"
    ORIGINAL_STAKING_NEURON_ID="$(ensure_neuron 2 "$ORIGINAL_STAKING_NEURON_ACCOUNT_ID" "5577006791947779410" "252460800")"
    STAKING_NEURONS="$(cat <<-EOM
$(ensure_neuron 3  "d452d54ab1efd6d3440c081030c56f922f4ae3855bce24274aa75eb98cda7876" "23437" "15778800")
$(ensure_neuron 4  "92e5922f64f7fd9ed987a8ec2888ab5fd58db22633855fe1bd7d15cd4553ba3f" "15875" "31557600")
$(ensure_neuron 5  "3c5a29df576daa304b8654a182f40d010bfa2a09e0899e3b41be7e6fe9a9900f" "24449" "47336400")
$(ensure_neuron 6  "af1d07f24d15b63bee021c5310388388d54a1bb19dc27812ea31ede49fcd9cea" "17568" "63115200")
$(ensure_neuron 7  "6c3e49f63c53ef14302486bdaa76316086c985a0a8ec1b8b6c97207f9f061b0d" "21844" "78894000")
$(ensure_neuron 8  "a0708ee96d8283e36040ad7cfb99efea48fd753304a3a310a638604d9e2845c6" "27031" "94672800")
$(ensure_neuron 9  "50f9f18e84a32269cd26ae817c1503a3d5dece93c3468ca3791377dce6f6f069" "13140" "110451600")
$(ensure_neuron 11 "95f76f8656ed2bfaeac8e212ad35effe565156f0596ace47bd149bd83cb8a0a8" "21212" "126230400")
$(ensure_neuron 12 "5a019ad9a5d8457b01843e649467a48716f494ea21bcb61da1deca2962ebc20d" "25565" "142009200")
$(ensure_neuron 13 "1c18fa79bf5c98430a85f2a662e81e66fc7a292142ae095efb3edec291eb9507" "17161" "157788000")
$(ensure_neuron 14 "9afc600aad8020ff17fce6471dcd4475bec55289718f8116ee49a1b7de5a05ce" "14950" "173566800")
$(ensure_neuron 15 "77372f05c2588a84956178083d86913c7deb7769c1c948cf05add7331f3614dd" "17217" "189345600")
$(ensure_neuron 16 "dfec9e1f20c45e5e8ed25a8f34ccca5447d4d92ead17613e07d8a7450eb3dba3" "27310" "205124400")
$(ensure_neuron 17 "3b1dbe7a4c9a7ebc262c8e809cd111a1da9eea1dcb1ef7e382b3f72ee892502e" "15353" "220903200")
$(ensure_neuron 18 "9ed781d2ba7b63fd46c7f5bcceca94470b1f94524215e470aa188ef20958b848" "26064" "236682000")
${ORIGINAL_STAKING_NEURON_ID}
EOM
)"
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

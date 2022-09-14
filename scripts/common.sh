#!/usr/bin/env bash

export IC_VERSION=dd3a710b03bd3ae10368a91b255571d012d1ec2f

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

make_neuron() {
  local NEURON_ACCOUNT_ID="$1"
  local NEURON_MEMO="$2"
  local NEURON_DELAY="${3:-0}"
  local PROPOSAL_NEURON_ID="$4"
  # Create a neuron
  >&2 echo "Transfer 1 ICP to $NEURON_ACCOUNT_ID, memo: $NEURON_MEMO"
  >&2 dfx ledger transfer "$NEURON_ACCOUNT_ID" --memo "$NEURON_MEMO" --amount "1.00"
  >&2 echo "Claim neuron by memo: $NEURON_MEMO"
  local NEURON_ID=$(dfx canister call governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })" \
    | grep -o "id = [0-9_]\+" \
    | grep -o "[0-9_]\+")
  >&2 echo "Created neuron: $NEURON_ID"

  # Add the deposits canister as a hotkey
  >&2 echo "Add hot key to neuron"
  >&2 "$DIR/addHotKey.sh" local "$NEURON_ID"

  # Set the delay
  if [ "$NEURON_DELAY" -gt 0 ]; then
      >&2 echo "Set the neuron delay"
      >&2 "$DIR/delayNeuron.sh" local "$NEURON_ID" "$NEURON_DELAY"
  fi

  if [ -n "$PROPOSAL_NEURON_ID" ]; then
      >&2 echo "Set staking neuron to follow proposal neuron"
      >&2 "$DIR/followNeuron.sh" local "$NEURON_ID" "$PROPOSAL_NEURON_ID"
  fi

  echo "$NEURON_ID"
}

export PROPOSAL_NEURON_ACCOUNT_ID="02231a0463394a9a040a4faac9e1fbe3bc5da96898d408ae7892ad98b8df7a7f"
export ORIGINAL_STAKING_NEURON_ACCOUNT_ID="94d4eddb1a4f1ef7a99bc5e89b21a1554303258884c35b5daba251fcf409d465"

local_neurons() {
  local OUT="$DIR/../.dfx/local/neurons.csv"
  if ! test -f "$OUT" ; then
    <&2 echo "Creating local neurons file: $OUT"
    PROPOSAL_NEURON_ID=$(make_neuron "$PROPOSAL_NEURON_ACCOUNT_ID" "1063793040729364723")
    (cat <<-EOM
$PROPOSAL_NEURON_ID
$(make_neuron "$ORIGINAL_STAKING_NEURON_ACCOUNT_ID" "5577006791947779410" "252460800" "$PROPOSAL_NEURON_ID")
$(make_neuron "d452d54ab1efd6d3440c081030c56f922f4ae3855bce24274aa75eb98cda7876" "23437" "15778800" "$PROPOSAL_NEURON_ID")
$(make_neuron "92e5922f64f7fd9ed987a8ec2888ab5fd58db22633855fe1bd7d15cd4553ba3f" "15875" "31557600" "$PROPOSAL_NEURON_ID")
$(make_neuron "3c5a29df576daa304b8654a182f40d010bfa2a09e0899e3b41be7e6fe9a9900f" "24449" "47336400" "$PROPOSAL_NEURON_ID")
$(make_neuron "af1d07f24d15b63bee021c5310388388d54a1bb19dc27812ea31ede49fcd9cea" "17568" "63115200" "$PROPOSAL_NEURON_ID")
$(make_neuron "6c3e49f63c53ef14302486bdaa76316086c985a0a8ec1b8b6c97207f9f061b0d" "21844" "78894000" "$PROPOSAL_NEURON_ID")
$(make_neuron "a0708ee96d8283e36040ad7cfb99efea48fd753304a3a310a638604d9e2845c6" "27031" "94672800" "$PROPOSAL_NEURON_ID")
$(make_neuron "50f9f18e84a32269cd26ae817c1503a3d5dece93c3468ca3791377dce6f6f069" "13140" "110451600" "$PROPOSAL_NEURON_ID")
$(make_neuron "95f76f8656ed2bfaeac8e212ad35effe565156f0596ace47bd149bd83cb8a0a8" "21212" "126230400" "$PROPOSAL_NEURON_ID")
$(make_neuron "5a019ad9a5d8457b01843e649467a48716f494ea21bcb61da1deca2962ebc20d" "25565" "142009200" "$PROPOSAL_NEURON_ID")
$(make_neuron "1c18fa79bf5c98430a85f2a662e81e66fc7a292142ae095efb3edec291eb9507" "17161" "157788000" "$PROPOSAL_NEURON_ID")
$(make_neuron "9afc600aad8020ff17fce6471dcd4475bec55289718f8116ee49a1b7de5a05ce" "14950" "173566800" "$PROPOSAL_NEURON_ID")
$(make_neuron "77372f05c2588a84956178083d86913c7deb7769c1c948cf05add7331f3614dd" "17217" "189345600" "$PROPOSAL_NEURON_ID")
$(make_neuron "dfec9e1f20c45e5e8ed25a8f34ccca5447d4d92ead17613e07d8a7450eb3dba3" "27310" "205124400" "$PROPOSAL_NEURON_ID")
$(make_neuron "3b1dbe7a4c9a7ebc262c8e809cd111a1da9eea1dcb1ef7e382b3f72ee892502e" "15353" "220903200" "$PROPOSAL_NEURON_ID")
$(make_neuron "9ed781d2ba7b63fd46c7f5bcceca94470b1f94524215e470aa188ef20958b848" "26064" "236682000" "$PROPOSAL_NEURON_ID")
EOM
) >"$OUT"
  fi
  cat "$OUT"
}

local_neuron() {
  local INDEX="${1:-1}"
  local_neurons | awk "NR == ${INDEX}"
}


#!/usr/bin/env bash

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
  local NEURON_ID=$(dfx canister call nns-governance claim_or_refresh_neuron_from_account "(record { controller = opt principal \"$(dfx identity get-principal)\" ; memo = $NEURON_MEMO : nat64 })" \
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

export PROPOSAL_NEURON_ACCOUNT_ID="1130EB895DBCBBF6666BE7801D703E862438C62BFA45DB5367E718B5AA83DBE8"
export ORIGINAL_STAKING_NEURON_ACCOUNT_ID="205510AB3C25AFC945632ABC550FE773681918BC24DFB60C8432DC4AFADB845F"

local_neurons() {
  local OUT="$DIR/../.dfx/local/neurons.csv"
  if ! test -f "$OUT" ; then
    <&2 echo "Creating local neurons file: $OUT"
    PROPOSAL_NEURON_ID=$(make_neuron "$PROPOSAL_NEURON_ACCOUNT_ID" "1063793040729364723")
    (cat <<-EOM
$PROPOSAL_NEURON_ID
$(make_neuron "$ORIGINAL_STAKING_NEURON_ACCOUNT_ID" "5577006791947779410" "252460800" "$PROPOSAL_NEURON_ID")
$(make_neuron "c8f4681d688dc8fdeab5af78cff997329eabec0ced7b423cc9682c8a85731bc4" "23437" "15778800" "$PROPOSAL_NEURON_ID")
$(make_neuron "06b0d927dac9a9b51727ab4178c0ee3ba518795238b11dd99a8246a298430146" "15875" "31557600" "$PROPOSAL_NEURON_ID")
$(make_neuron "643fe97fd09a65c3f2573df2b80f5e8baeb5ce8deeb68ec4a7cdfb6a9712e054" "24449" "47336400" "$PROPOSAL_NEURON_ID")
$(make_neuron "e2336a961dec9063fa24fffd7282eb02bd54e096bf44613cd6fb38320c497310" "17568" "63115200" "$PROPOSAL_NEURON_ID")
$(make_neuron "e4d85ba596ce0257510b8a622ebd756e87b1776373270d98a784d09b59307ff7" "21844" "78894000" "$PROPOSAL_NEURON_ID")
$(make_neuron "b3445b9618c7d342ba7a3f1bc13143c6c8307465516db43fa3e6715cd3569b12" "27031" "94672800" "$PROPOSAL_NEURON_ID")
$(make_neuron "bbc71c36b21b8e821b04552feed6d37ce8d5c73d4b74da62c2fd5cd8309a6a4e" "13140" "110451600" "$PROPOSAL_NEURON_ID")
$(make_neuron "27d39c5df523c9d82ce555f3f04cdc2121536dc7c03e2c3271c33d3ec7e513c6" "21212" "126230400" "$PROPOSAL_NEURON_ID")
$(make_neuron "a3ffc954e16a5c7144a591a12adb6bf4a893fec4aca10fda9649525cd0795d70" "25565" "142009200" "$PROPOSAL_NEURON_ID")
$(make_neuron "1c1e0a55e0b2fa6dca7e8be469658e1baf1fefac5943a940d72a8ddb02902c8d" "17161" "157788000" "$PROPOSAL_NEURON_ID")
$(make_neuron "c2ccd3cfc9ea70f9a3df8ae68f63fb79df5ae5bc2ebcb820e2e4ea6a00fa86f3" "14950" "173566800" "$PROPOSAL_NEURON_ID")
$(make_neuron "d0445a4aebba33443ceaa778018def82fed7646be5bb9b748b044c006fb5e935" "17217" "189345600" "$PROPOSAL_NEURON_ID")
$(make_neuron "0a3a4be00a894d8af65923de7c93aaa66aff435259324c73234e8be586e726ce" "27310" "205124400" "$PROPOSAL_NEURON_ID")
$(make_neuron "1c5e7f353d9d666333b237acd6172cc06a28780dacd6325627733d509de24fcb" "15353" "220903200" "$PROPOSAL_NEURON_ID")
$(make_neuron "ab5d8b5879eeb2f79fcc32a1fcb369d0abe8765631128c64ffec654a14841181" "26064" "236682000" "$PROPOSAL_NEURON_ID")
EOM
) >"$OUT"
  fi
  cat "$OUT"
}

local_neuron() {
  local INDEX="${1:-1}"
  local_neurons | awk "NR == ${INDEX}"
}


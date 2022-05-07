#!/bin/bash

NETWORK="${1:-local}"

existing_neuron_id() {
  (dfx canister call governance \
    list_neurons \
    '(record { neuron_ids = vec {}; include_neurons_readable_by_caller = true})' \
    | grep -o "id = [0-9_]\+" \
    | grep -o "[0-9_]\+") \
}

make_neuron() {
  >&2 echo "Neuron not found"
  exit 1
}

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    NEURON_ID="16_136_654_443_876_485_299"
    ;;

  "local")
    DFX_OPTS=""
    NEURON_ID="$(existing_neuron_id || make_neuron)"
    ;;

  *)
    echo "unknown network: $NETWORK" >&2
    exit 1
    ;;
esac

canister() {
  dfx canister $DFX_OPTS "$@"
}

read -r -d '' MSG << EOM
(
  record {
    id = null;
    command = opt variant {
      Configure = record {
        operation = opt variant {
          AddHotKey = record {
            new_hot_key = opt principal "$(canister id deposits)"
          }
        }
      }
    };
    neuron_id_or_subaccount = opt variant {
      NeuronId = record { id = $NEURON_ID : nat64 }
    };
  },
)
EOM

canister call governance manage_neuron "$MSG"

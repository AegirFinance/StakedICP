#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

NETWORK="${1:-local}"
NEURON_ID="${2}"

case "$NETWORK" in
  "ic")
    DFX_OPTS="--network ic"
    ;;

  "local")
    DFX_OPTS=""
    ;;

  *)
    echo "unknown network: $NETWORK" >&2
    exit 1
    ;;
esac

if [ -z "$NEURON_ID" ]; then
    echo "usage: ./scripts/addHotKey.sh NETWORK NEURON_ID" >&2
    exit 1
fi

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

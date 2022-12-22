
#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

NETWORK="${1:-local}"
NEURON_ID="${2}"
DELAY="${3}"

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

if [ -z "$NEURON_ID" ] || [ -z "$DELAY" ]; then
    echo "usage: ./scripts/delayNeuron.sh NETWORK NEURON_ID DELAY_SECONDS" >&2
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
          IncreaseDissolveDelay = record {
            additional_dissolve_delay_seconds = ${DELAY} : nat32
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

canister call nns-governance manage_neuron "$MSG"

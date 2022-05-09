#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

set -e

NETWORK="${1:-local}"
FOLLOWER_ID="$2"
FOLLOWEE_ID="$3"
TOPIC="$4"

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

if [[ "$FOLLOWER_ID" == "" ]] || [[ "$FOLLOWEE_ID" == "" ]]; then
    echo "usage: ./scripts/followNeuron.sh NETWORK FOLLOWER_ID FOLLOWEE_ID [TOPIC]" >&2
    exit 1
fi

canister() {
  dfx canister $DFX_OPTS "$@"
}

followNeuron() {
    local TOPIC="$1"
    echo "${FOLLOWER_ID} following ${FOLLOWEE_ID} on topic ${TOPIC}"
    canister call governance manage_neuron "(
      record {
        id = null;
        command = opt variant {
          Follow = record {
            topic = ${TOPIC} : int32;
            followees = vec {
                record { id = ${FOLLOWEE_ID} : nat64 };
            }
          }
        };
        neuron_id_or_subaccount = opt variant {
          NeuronId = record { id = $FOLLOWER_ID : nat64 }
        };
      },
    )"
}

TOPIC_UNSPECIFIED=0
TOPIC_NEURON_MANAGEMENT=1
TOPIC_GOVERNANCE=4

if [ -z "$TOPIC" ]; then
    >&2 followNeuron "$TOPIC_UNSPECIFIED"
    >&2 followNeuron "$TOPIC_NEURON_MANAGEMENT"
    >&2 followNeuron "$TOPIC_GOVERNANCE"
else
    >&2 followNeuron "$TOPIC"
fi

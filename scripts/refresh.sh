#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

NETWORK="$1"
NEURON_ID="$2"

if [ -z "$NETWORK" ] || [ -z "$NEURON_ID" ]; then
  echo "usage: ./refresh.sh NETWORK NEURON_ID" >&2
  exit 1
fi

read -r -d '' MSG << EOM
(
  record {
    id = null;
    command = opt variant {
      ClaimOrRefresh = record {
        by = opt variant {
          NeuronIdOrSubaccount = record {}
        };
      }
    };
    neuron_id_or_subaccount = opt variant {
      NeuronId = record { id = $NEURON_ID : nat64 }
    };
  },
)
EOM

dfx canister --network "$NETWORK" call governance manage_neuron "$MSG"

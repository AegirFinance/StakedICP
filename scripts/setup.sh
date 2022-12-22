#!/bin/bash

set -e

NETWORK=local

#or neuron in 16136654443876485299 1403496971162317831 2863272345781569901 3610619949984390952 3874813872191909268 4271422526962282763 4283935519248289268 5200822003571164690 5485243332413224513 7868563808780006636 8831486599406697682 15220551358037404712 15588418587512451888 15871449415035457890 16073048906142086194 17452044821884135920; do
#   echo deposits.addStakingNeuron $neuron
#   dfx canister --network $NETWORK call deposits addStakingNeuron "$neuron"
#one

echo deposits.setInitialSnapshot
dfx canister --network $NETWORK call deposits setInitialSnapshot

echo deposits.setAppliedInterest
dfx canister --network $NETWORK call deposits setAppliedInterest "$(cat appliedInterest.did)"

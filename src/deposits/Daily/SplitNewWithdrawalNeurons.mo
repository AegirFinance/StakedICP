import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Staking "../Staking";
import Withdrawals "../Withdrawals";

module {
    public type SplitNewWithdrawalNeuronsResult = Result.Result<[Neurons.NeuronResult], Neurons.NeuronsError>;

    // Job is the step of the daily job which splits of new withdrawal neurons
    // to ensure we have enough dissolving to satisfy pending withdrawals.
    public class Job(args: {
        neurons: Neurons.Manager;
        staking: Staking.Manager;
        withdrawals: Withdrawals.Manager;
    }) {
        // Split off as many staking neurons as we need to satisfy pending
        // withdrawals.
        public func start(): async SplitNewWithdrawalNeuronsResult {
            // figure out how much we have dissolving for withdrawals
            let dissolving = args.withdrawals.totalDissolving();
            let pending = args.withdrawals.totalPending();

            // Split and dissolve enough new neurons to satisfy pending withdrawals
            if (pending <= dissolving) {
                return #ok([]);
            };
            // figure out how much we need dissolving for withdrawals
            let needed = pending - dissolving;
            // Split the difference off from staking neurons
            switch (args.staking.splitNeurons(needed)) {
                case (#err(err)) {
                    #err(err)
                };
                case (#ok(toSplit)) {
                    // Do the splits on the nns and find the new neurons.
                    let newNeurons = Buffer.Buffer<Neurons.NeuronResult>(toSplit.size());
                    for ((id, amount) in toSplit.vals()) {
                        // TODO: If we didn't care about the results here we
                        // could use `ignore` instead of `await`. Maybe we
                        // could store errors somewhere in a stable var? We
                        // could write to that from within splitAndDissolve, so
                        // this func could be atomic.
                        newNeurons.add(await splitAndDissolve(id, amount));
                    };
                    #ok(newNeurons.toArray())
                };
            }
        };

        private func splitAndDissolve(id: Nat64, amount: Nat64): async Neurons.NeuronResult {
            try {
                // Split off a new neuron
                let n = switch (await args.neurons.split(id, amount)) {
                    case (#err(err)) { return #err(err) };
                    case (#ok(neuron)) { neuron };
                };
                // Start it dissolving
                let d = switch (await dissolveNeuron(n)) {
                    case (#err(err)) { return #err(err) };
                    case (#ok(neuron)) { neuron };
                };
                ignore args.withdrawals.addNeurons([d]);
                #ok(d)
            } catch (error) {
                #err(#Other(Error.message(error)));
            }
        };

        private func dissolveNeuron(n: Neurons.Neuron): async Neurons.NeuronResult {
            switch (n.dissolveState) {
                case (?#DissolveDelaySeconds(delay)) {
                    // Make sure the neuron is dissolving
                    try {
                        await args.neurons.dissolve(n.id)
                    } catch (error) {
                        #err(#Other(Error.message(error)))
                    }
                };
                case (_) { #ok(n) };
            }
        };
    };
};

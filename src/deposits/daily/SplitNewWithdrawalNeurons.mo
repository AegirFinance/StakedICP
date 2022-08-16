import Buffer "mo:base/Buffer";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Staking "../Staking";
import Withdrawals "../Withdrawals";

module {
    public type UpgradeData = {
        #v1: {
            result: ?SplitNewWithdrawalNeuronsResult;
        };
    };

    public type SplitNewWithdrawalNeuronsResult = Result.Result<[Neurons.Neuron], Neurons.NeuronsError>;

    // Job is the step of the daily job which splits of new withdrawal neurons
    // to ensure we have enough dissolving to satisfy pending withdrawals.
    public class Job(args: {
        neurons: Neurons.Manager;
        staking: Staking.Manager;
        withdrawals: Withdrawals.Manager;
    }) {
        private var result: ?SplitNewWithdrawalNeuronsResult = null;

        // ===== GETTER/SETTER FUNCTIONS =====

        public func getResult(): ?SplitNewWithdrawalNeuronsResult {
            result
        };

        // ===== JOB START FUNCTION =====

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
                    let newNeurons = Buffer.Buffer<Neurons.Neuron>(toSplit.size());
                    for ((id, amount) in toSplit.vals()) {
                        switch (await args.neurons.split(id, amount)) {
                            case (#err(err)) {
                                // TODO: Error handling
                            };
                            case (#ok(n)) {
                                newNeurons.add(n);
                            };
                        };
                    };
                    // Pass the new neurons into the withdrawals manager.
                    switch (await dissolveNeurons(newNeurons.toArray())) {
                        case (#err(err)) { #err(err) };
                        case (#ok(newNeurons)) { #ok(args.withdrawals.addNeurons(newNeurons)) };
                    }
                };
            }
        };

        private func dissolveNeurons(ns: [Neurons.Neuron]): async Neurons.NeuronsResult {
            let newNeurons = Buffer.Buffer<Neurons.Neuron>(ns.size());
            for (n in ns.vals()) {
                let neuron = switch (n.dissolveState) {
                    case (?#DissolveDelaySeconds(delay)) {
                        // Make sure the neuron is dissolving
                        switch (await args.neurons.dissolve(n.id)) {
                            case (#err(err)) {
                                return #err(err);
                            };
                            case (#ok(n)) {
                                n
                            };
                        }
                    };
                    case (_) { n };
                };
                newNeurons.add(neuron);
            };
            #ok(newNeurons.toArray())
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade(): ?UpgradeData {
            return ?#v1({
                result = result;
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    result := data.result;
                };
                case (_) { return; }
            };
        };
    };
};

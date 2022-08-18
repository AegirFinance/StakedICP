import Array "mo:base/Array";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Withdrawals "../Withdrawals";

module {
    public type MergeWithdrawalMaturityResult = [Neurons.NeuronResult];

    // Job is the step of the daily job which merges the maturity for out
    // dissolving withdrawal neurons.
    public class Job(args: {
        neurons: Neurons.Manager;
        withdrawals: Withdrawals.Manager;
    }) {
        // Merge maturity on dissolving neurons. Merged maturity here will be
        // disbursed when the neuron is dissolved, and will be a "bonus" put
        // towards filling pending withdrawals early.
        public func start(): async MergeWithdrawalMaturityResult {
            let merges = await args.neurons.mergeMaturities(args.withdrawals.ids(), 100);
            ignore args.withdrawals.addNeurons(
                Array.mapFilter<Neurons.NeuronResult, Neurons.Neuron>(
                    merges,
                    func(r) { Result.toOption(r) },
                )
            );
            merges
        };
    };
};

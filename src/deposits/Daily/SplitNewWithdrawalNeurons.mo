import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Staking "../Staking";
import Withdrawals "../Withdrawals";

module {
    public type SplitNewWithdrawalNeuronsResult = Result.Result<[(Nat64, Nat64)], Neurons.NeuronsError>;

    // Job is the step of the daily job which splits off new withdrawal neurons
    // to ensure we have enough dissolving to satisfy pending withdrawals.
    public class Job(args: {
        neurons: Neurons.Manager;
        staking: Staking.Manager;
        withdrawals: Withdrawals.Manager;
    }) {
        // Split off as many staking neurons as we need to satisfy pending
        // withdrawals.
        public func run(): async SplitNewWithdrawalNeuronsResult {
            //    a. Garbage-collect disbursed neurons from the withdrawal module tracking
            //       1. This should figure out which neurons *might* have been disbursed, and querying the
            //       governance canister to confirm their state. This will make it idempotent.
            //       2. If there are unknown dissolving neurons, they should be considered as new withdrawal
            //       neurons. This will make it idempotent.
            // TODO: Are disbursed neurons gone? or do they still show up in
            // the nns? If they are gone we need to query them and check
            // they're gone. And make sure they show up in the listing.
            let neurons = await args.neurons.list(null)
            let disbursedNeurons = Buffer.Buffer<Nat64>(0);
            let dissolvingNeurons = Buffer.Buffer<Neurons.Neuron>(0);
            for (neuron in neurons.vals()) {
                switch (neuron.dissolveState) {
                    // TODO: Figure this out
                }
            };
            ignore args.withdrawals.addNeurons(dissolvingNeurons.toArray());
            ignore args.withdrawals.removeDisbursedNeurons(disbursedNeurons.toArray());


            //    b. Query dissolving neurons total & pending total, to calculate dissolving target
            let dissolving = args.withdrawals.totalDissolving();
            let pending = args.withdrawals.totalPending();

            //    c. Return a list of which staking neurons to split and how much
            if (pending <= dissolving) {
                return #ok([]);
            };
            let needed = pending - dissolving;
            // Calculate how much to split off from staking neurons
            args.staking.splitNeurons(needed)
        };
    };
};

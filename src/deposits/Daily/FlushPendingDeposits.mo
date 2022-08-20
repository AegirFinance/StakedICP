import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Staking "../Staking";
import Withdrawals "../Withdrawals";
import Ledger "../../ledger/Ledger";
import Token "../../DIP20/motoko/src/token";

module {
    public type FlushPendingDepositsResult = [Ledger.TransferResult];

    public type AvailableBalanceFn = () -> Nat64;
    public type RefreshAvailableBalanceFn = () -> async Nat64;

    // Job is step of the daily process which transfers pending deposits (ICP
    // in the canister) through to pay off pending withdrawals, and top up the
    // neurons.
    public class Job(args: {
        ledger: Ledger.Self;
        neurons: Neurons.Manager;
        staking: Staking.Manager;
        token: Token.Token;
        withdrawals: Withdrawals.Manager;
    }) {
        // Use new incoming deposits to attempt to rebalance the buckets, where
        // "the buckets" are:
        // - pending withdrawals
        // - ICP in the canister
        // - staking neurons
        public func start(
            availableBalance: AvailableBalanceFn,
            refreshAvailableBalance: RefreshAvailableBalanceFn
        ): async FlushPendingDepositsResult {
            // Note, this races with the queued mints in ApplyInterest. Once
            // ApplyInterest's flushes are finished, the total supply might be
            // higher than what we see here.
            let tokenE8s = Nat64.fromNat((await args.token.getMetadata()).totalSupply);
            var canisterE8s = availableBalance();

            if (canisterE8s == 0) {
                return [];
            };

            // First try to use it fulfill pending deposits
            canisterE8s -= args.withdrawals.depositIcp(canisterE8s);
            if (canisterE8s == 0) {
                return [];
            };

            // Spread the remainder between staking neurons (retaining some in the canister).
            let transfers = args.staking.depositIcp(tokenE8s, canisterE8s, null);
            let results = Buffer.Buffer<Ledger.TransferResult>(transfers.size());
            for (transfer in transfers.vals()) {
                // Start the transfer. Best effort here. If the transfer fails,
                // it'll be retried next time. But awaiting, means we can
                // refresh the balance and staking neurons afterwards
                try {
                    results.add(await args.ledger.transfer(transfer));
                } catch (error) {
                    // This is fine. Transfer will be retried next time.
                }
            };
            if (transfers.size() > 0) {
                // If we did outbound transfers, refresh the ledger balance.
                ignore await refreshAvailableBalance();
                // Update the staked neuron balances after they've been topped up
                ignore await refreshAllStakingNeurons();
            };

            results.toArray();
        };

        // Refresh all neurons, fetching current data from the NNS. This is
        // needed e.g. if we have transferred more ICP into a staking neuron,
        // to update the cached balances.
        private func refreshAllStakingNeurons(): async ?Neurons.NeuronsError {
            for (id in args.staking.ids().vals()) {
                switch (await args.neurons.refresh(id)) {
                    case (#err(err)) { return ?err };
                    case (#ok(neuron)) {
                        ignore args.staking.addOrRefresh(neuron);
                    };
                };
            };
            return null;
        };
    };
};

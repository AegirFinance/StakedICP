import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

import Neurons "../Neurons";
import Staking "../Staking";
import Withdrawals "../Withdrawals";
import Ledger "../../ledger/Ledger";
import Token "../../DIP20/motoko/src/token";

module {
    public type UpgradeData = {
        #v1: {
            result: ?FlushPendingDepositsResult;
        };
    };

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
        private var result: ?FlushPendingDepositsResult = null;

        // ===== GETTER/SETTER FUNCTIONS =====

        public func getResult(): ?FlushPendingDepositsResult {
            result
        };

        // ===== JOB START FUNCTION =====

        // Use new incoming deposits to attempt to rebalance the buckets, where
        // "the buckets" are:
        // - pending withdrawals
        // - ICP in the canister
        // - staking neurons
        public func start(
            availableBalance: AvailableBalanceFn,
            refreshAvailableBalance: RefreshAvailableBalanceFn
        ): async FlushPendingDepositsResult {
            // Reset the result.
            result := null;

            let tokenE8s = Nat64.fromNat((await args.token.getMetadata()).totalSupply);
            let totalBalance = availableBalance();

            if (totalBalance == 0) {
                return [];
            };

            let applied = args.withdrawals.applyIcp(totalBalance);
            let balance = totalBalance - Nat64.min(totalBalance, applied);
            if (balance == 0) {
                return [];
            };

            let transfers = args.staking.depositIcp(tokenE8s, balance, null);
            let results = Buffer.Buffer<Ledger.TransferResult>(transfers.size());
            for (transfer in transfers.vals()) {
                // Start the transfer. Best effort here. If the transfer fails,
                // it'll be retried next time. But not awaiting means this function
                // is atomic.
                results.add(await args.ledger.transfer(transfer));
            };
            if (transfers.size() > 0) {
                // If we did outbound transfers, refresh the ledger balance afterwards.
                ignore await refreshAvailableBalance();
                // Update the staked neuron balances after they've been topped up
                ignore await refreshAllStakingNeurons();
            };

            results.toArray()
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

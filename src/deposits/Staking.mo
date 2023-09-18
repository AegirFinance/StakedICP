import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import NNS "./NNS";
import Neurons "./Neurons";
import Governance "../nns-governance";
import Ledger "../nns-ledger";
import Metrics "../metrics/types";

module {
    public let minimumStake: Nat64 = 100_000_000;
    public let minimumTransfer: Nat64 = 100_000_000;
    let icpFee: Nat64 = 10_000;
    let yearSeconds: Int = 31_557_600;

    public type UpgradeData = {
        #v1: {
            stakingNeurons: [(Text, Neurons.NeuronV1)];
        };
        #v2: {
            stakingNeurons: [(Text, Neurons.Neuron)];
        };
    };

    // The StakingManager manages our staking. Specifically, the staking
    // neurons, routing deposits to the neurons, merging maturity, and
    // splitting new neurons off to be dissolved for withdrawals.
    public class Manager(args: {
        governance: Principal;
        neurons: Neurons.Manager;
    }) {
        // 30 days
        private var second = 1_000_000_000;
        private var minute = 60*second;
        private var hour = 60*minute;
        private var day = 24*hour;

        private let governance: Governance.Interface = actor(Principal.toText(args.governance));
        private var stakingNeurons = TrieMap.TrieMap<Text, Neurons.Neuron>(Text.equal, Text.hash);

        public func metrics(): Buffer.Buffer<Metrics.Metric> {
            let ms = Buffer.Buffer<Metrics.Metric>(2);
            ms.add({
                name = "neuron_count";
                t = "gauge";
                help = ?"count of the neuron(s) by type";
                labels = [("type", "staking")];
                value = Nat.toText(stakingNeurons.size());
            });
            ms.add({
                name = "neuron_balance_e8s";
                t = "gauge";
                help = ?"e8s balance of the neuron(s)";
                labels = [("type", "staking")];
                value = Nat64.toText(totalStaking());
            });
            ms
        };

        // Lists the staking neurons
        public func list(): [Neurons.Neuron] {
            let b = Buffer.Buffer<Neurons.Neuron>(stakingNeurons.size());
            for (neuron in stakingNeurons.vals()) {
                b.add(neuron);
            };
            return b.toArray();
        };

        // Balances is the balances of the staking neurons
        public func balances(): [(Nat64, Nat64)] {
            let b = Buffer.Buffer<(Nat64, Nat64)>(stakingNeurons.size());
            for (neuron in stakingNeurons.vals()) {
                b.add((neuron.id, Neurons.balance(neuron)));
            };
            return b.toArray();
        };

        // Sum the balances of all staking neurons
        public func totalStaking(): Nat64 {
          var sum: Nat64 = 0;
          for (neuron in stakingNeurons.vals()) {
              sum += Neurons.balance(neuron);
          };
          sum
        };

        // Returns array of delays (seconds) and the amount (e8s) becoming
        // available after that delay.
        //
        // TODO: Group by delay, incase there is any overlap
        //
        // TODO: Account for the stakedMaturity as well here, once we can
        // handle that in the splitNeurons method below.
        public func availableLiquidityGraph(): [(Int, Nat64)] {
            var sum: Nat64 = 0;
            let b = Buffer.Buffer<(Int, Nat64)>(stakingNeurons.size());
            for (neuron in stakingNeurons.vals()) {
                if (neuron.cachedNeuronStakeE8s > minimumStake) {
                    b.add((Neurons.dissolveDelay(neuron), neuron.cachedNeuronStakeE8s - minimumStake));
                };
            };
            Array.sort(b.toArray(), func(a: (Int, Nat64), b: (Int, Nat64)): Order.Order {
                Int.compare(a.0, b.0)
            })
        };

        // Get the ids of the staking neurons
        public func ids(): [Nat64] {
            Iter.toArray(Iter.map(
                stakingNeurons.vals(),
                func (n: Neurons.Neuron): Nat64 { n.id }
            ))
        };

        public func addOrRefreshAll(neurons: [Neurons.Neuron]): [Bool] {
            let b = Buffer.Buffer<Bool>(neurons.size());
            for (neuron in neurons.vals()) {
                b.add(addOrRefresh(neuron));
            };
            b.toArray()
        };

        // addOrRefresh idempotently adds a staking neuron, or refreshes it's balance
        public func addOrRefresh(neuron: Neurons.Neuron): Bool {
            let id = Nat64.toText(neuron.id);
            let isNew = Option.isNull(stakingNeurons.get(id));
            stakingNeurons.put(id, neuron);
            isNew
        };

        // Idempotently remove a neuron which should be forgotten about.
        public func removeNeurons(ids: [Nat64]): () {
            for (id in ids.vals()) {
                stakingNeurons.delete(Nat64.toText(id));
            };
        };

        // helper to allow sorting neurons by balance
        func compareBalance(a: Neurons.Neuron, b: Neurons.Neuron): Order.Order {
            Nat64.compare(Neurons.balance(a), Neurons.balance(b))
        };

        // helper to allow sorting neurons by dissolve delay
        func compareDissolveDelay(a: Neurons.Neuron, b: Neurons.Neuron): Order.Order {
            Int.compare(Neurons.dissolveDelay(a), Neurons.dissolveDelay(b))
        };

        // Calculate how much we should aim to have in each neuron, and in
        // cash. Each will be the same for now.
        public func rebalancingTarget(totalE8s: Nat64): Nat64 {
            // Assume there is one neuron per 6 months.. no duplicates.
            // All the same share for now. +1 is for first 6 months in cash
            totalE8s / (Nat64.fromNat(stakingNeurons.size())+1)
        };

        // depositIcp takes an amount of e8s to deposit, and returns a list of
        // transfers to make, routing the deposit ICP to the staking neurons.
        public func depositIcp(totalE8s: Nat64, canisterE8s: Nat64, fromSubaccount: ?NNS.Subaccount): [Ledger.TransferArgs] {
            if (canisterE8s <= minimumTransfer) {
                return [];
            };

            // Find the target balance for each neuron + cash
            let target = rebalancingTarget(totalE8s);

            // Sort neurons (which are at least minimumTransfer under-target)
            // from lowest to highest balance
            let neurons = Array.sort(
                Array.filter<Neurons.Neuron>(
                    Iter.toArray(stakingNeurons.vals()),
                    func(n) { (Neurons.balance(n) + minimumTransfer) <= target }
                ),
                compareBalance
            );

            var remaining = canisterE8s;
            let b = Buffer.Buffer<Ledger.TransferArgs>(neurons.size());
            for (n in neurons.vals()) {
                let amount = Nat64.min(remaining, target - Neurons.balance(n));

                // If we're close to the target, stop here. Avoid small
                // transfers, to save on fees. At this point either neurons are
                // almost full, or remainder is too small.
                if (amount < minimumTransfer) {
                    return b.toArray();
                };

                remaining -= amount;

                if (remaining < icpFee) {
                    return b.toArray();
                };
                remaining -= icpFee;

                b.add({
                    memo : Nat64    = 0;
                    from_subaccount = Option.map(fromSubaccount, Blob.toArray);
                    to              = Blob.toArray(n.accountId);
                    amount          = { e8s = amount };
                    fee             = { e8s = icpFee };
                    created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
                })
            };
            b.toArray()
        };

        // splitNeurons attempts to split off enough new dissolving neurons to
        // make sure that at least "amount" liquidity will become available.
        // This is used to ensure there is at least enough ICP dissolving in
        // the NNS to eventually fulfill all pending deposits.
        //
        // If successful, it returns: [(NeuronID, AmountToSplit+Fee)]
        //
        // TODO: Account for stakedMaturity here and handle that as part of the
        // split. This means that occasionally we may want to keep the newly
        // split neuron, and start dissolving the original to reify the earned
        // maturity.
        public func splitNeurons(e8s: Nat64): Result.Result<[(Nat64, Nat64)], Neurons.NeuronsError> {
            if (e8s == 0) {
                return #ok([]);
            };

            // Sort by shortest dissolve delay. We'll split off the shorter
            // neurons first, so that withdrawals are processed faster, and any
            // deposit/withdrawal churn is confined to short-term neurons,
            // allowing longer-term liquidity to maximize earning.
            let neurons = Array.sort(Iter.toArray(stakingNeurons.vals()), compareDissolveDelay);

            // Split as much as we can off each, until we are satisfied
            // To ensure at minimum e8s liquidity will be split, we must do at
            // least one split. The smallest split we can do it "minimumStake".
            var remaining = Nat64.max(e8s, minimumStake);
            let toSplit = Buffer.Buffer<(Nat64, Nat64)>(0);
            for (n in neurons.vals()) {
                // Filter out any we can't split (balance < 2icp+fee)
                if (remaining > 0 and n.cachedNeuronStakeE8s >= (minimumStake*2)+icpFee) {
                    let amountToSplit = Nat64.min(remaining, n.cachedNeuronStakeE8s - minimumStake - icpFee);
                    remaining -= amountToSplit;
                    toSplit.add((n.id, amountToSplit+icpFee));
                };
            };

            // If we couldn't get enough, fail w insufficient liquidity
            if (remaining > 0) {
                return #err(#InsufficientStake);
            };

            return #ok(toSplit.toArray());
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade(): ?UpgradeData {
            return ?#v2({
                stakingNeurons = Iter.toArray(stakingNeurons.entries());
            });
        };

        public func postupgrade(upgradeData: ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    let neurons = Buffer.Buffer<(Text, Neurons.Neuron)>(data.stakingNeurons.size());
                    for ((id, neuron) in Iter.fromArray(data.stakingNeurons)) {
                        neurons.add((id, {
                            id = neuron.id;
                            accountId = neuron.accountId;
                            dissolveState = neuron.dissolveState;
                            cachedNeuronStakeE8s = neuron.cachedNeuronStakeE8s;
                            stakedMaturityE8sEquivalent = null;
                        }));
                    };
                    postupgrade(?#v2({
                        stakingNeurons = neurons.toArray();
                    }));
                };
                case (?#v2(data)) {
                    stakingNeurons := TrieMap.fromEntries(
                        data.stakingNeurons.vals(),
                        Text.equal,
                        Text.hash
                    );
                };
                case (_) { return; };
            };
        };
    }
}

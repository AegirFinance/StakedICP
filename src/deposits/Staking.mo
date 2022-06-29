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

import Account "./Account";
import Neurons "./Neurons";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";

module {
    let minimumStake: Nat64 = 100_000_000;
    let icpFee: Nat64 = 10_000;
    let yearSeconds: Int = 31_557_600;

    public type UpgradeData = {
        #v1: {
            stakingNeurons: [(Text, Neurons.Neuron)];
        };
    };

    public type Metrics = {
    };


    public type MergeMaturityResult = Result.Result<
        Neurons.Neuron,
        Neurons.NeuronsError
    >;

    // The StakingManager manages our staking. Specifically, the staking
    // neurons, routing deposits to the neurons, merging maturity, and
    // splitting new neurons off to be dissolved.
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

        public func metrics(): Metrics {
            return {};
        };

        public func list(): [{ id : Governance.NeuronId ; accountId : Text }] {
            let b = Buffer.Buffer<{ id : Governance.NeuronId ; accountId : Text }>(stakingNeurons.size());
            for (neuron in stakingNeurons.vals()) {
                b.add({
                    id = { id = neuron.id };
                    accountId = Account.toText(neuron.accountId);
                });
            };
            return b.toArray();
        };

        // balances is the balances of the staking neurons
        public func balances(): [(Nat64, Nat64)] {
            let b = Buffer.Buffer<(Nat64, Nat64)>(stakingNeurons.size());
            for (neuron in stakingNeurons.vals()) {
                b.add((neuron.id, neuron.cachedNeuronStakeE8s));
            };
            return b.toArray();
        };

        // Returns array of delays (seconds) and the amount (e8s) becoming
        // available after that delay.
        // TODO: Implement this properly.
        public func availableLiquidityGraph(): [(Int, Nat64)] {
            var sum: Nat64 = 0;
            for (neuron in stakingNeurons.vals()) {
                sum += neuron.cachedNeuronStakeE8s;
            };

            // 8 years in seconds, and sum
            return [(252_460_800, sum)];
        };

        public func ids(): [Nat64] {
            Iter.toArray(Iter.map(
                stakingNeurons.vals(),
                func (n: Neurons.Neuron): Nat64 { n.id }
            ))
        };

        // addOrRefresh idempotently adds a staking neuron, or refreshes it's balance
        public func addOrRefresh(id: Nat64): async Neurons.NeuronResult {
            switch (await args.neurons.refresh(id)) {
                case (#err(err)) {
                    return #err(err);
                };
                case (#ok(neuron)) {
                    stakingNeurons.put(Nat64.toText(id), neuron);
                    return #ok(neuron);
                };
            };
        };

        public func maturities(): async [(Nat64, Nat64)] {
            await args.neurons.maturities(ids())
        };

        // TODO: How do we take our cut here?
        // TODO: Move this to the new StakingManager module and use mergeMaturity above
        public func mergeMaturity(percentage: Nat32): async [Neurons.NeuronResult] {
            let merges = await args.neurons.mergeMaturities(ids(), percentage);
            for (m in merges.vals()) {
                switch (m) {
                    case (#err(err)) { };
                    case (#ok(neuron)) {
                        stakingNeurons.put(Nat64.toText(neuron.id), neuron);
                    };
                };
            };
            merges
        };

        func compareBalance(a: Neurons.Neuron, b: Neurons.Neuron): Order.Order {
            Nat64.compare(a.cachedNeuronStakeE8s, b.cachedNeuronStakeE8s)
        };

        func compareDissolveDelay(a: Neurons.Neuron, b: Neurons.Neuron): Order.Order {
            Nat64.compare(Neurons.dissolveDelay(a), Neurons.dissolveDelay(b))
        };

        // Calculate how much we should aim to have in each neuron, and in
        // cash. (The same for now).
        public func rebalancingTarget(totalE8s: Nat64): Nat64 {
            // Assume there is one neuron per 6 months.. no duplicates.
            // All the same share for now. +1 is for first 6 months in cash
            totalE8s / (Nat64.fromNat(stakingNeurons.size())+1)
        };

        // depositIcp takes an amount of e8s to deposit, and returns a list of
        // transfers to make.
        public func depositIcp(newE8s: Nat64, fromSubaccount: ?Account.Subaccount): [Ledger.TransferArgs] {
            if (newE8s <= icpFee) {
                return [];
            };

            let neurons = Array.sort(Iter.toArray(stakingNeurons.vals()), compareBalance);

            var totalE8s: Nat64 = 0;
            for (n in neurons.vals()) {
                totalE8s += n.cachedNeuronStakeE8s;
            };

            var remaining = newE8s;
            let b = Buffer.Buffer<Ledger.TransferArgs>(neurons.size());
            let target = rebalancingTarget(totalE8s+newE8s);
            for (n in neurons.vals()) {
                if (remaining < minimumStake) {
                    return b.toArray();
                };

                if (target > n.cachedNeuronStakeE8s) {
                    var amount = Nat64.min(
                        remaining,
                        Nat64.max(
                            minimumStake,
                            target - n.cachedNeuronStakeE8s
                        )
                    );
                    remaining -= amount;
                    if (remaining < minimumStake) {
                        // If there's <1ICP left, chuck the remainder in here.
                        amount += remaining;
                        remaining := 0;
                    };
                    b.add({
                        memo : Nat64    = 0;
                        from_subaccount = Option.map(fromSubaccount, Blob.toArray);
                        to              = Blob.toArray(n.accountId);
                        amount          = { e8s = amount - icpFee };
                        fee             = { e8s = icpFee };
                        created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
                    })
                }
            };
            b.toArray()
        };

        // splitNeurons attempts to split off enough new dissolving neurons to
        // make "amount" liquidity available.
        public func splitNeurons(e8s: Nat64): async Result.Result<[Neurons.Neuron], Neurons.NeuronsError> {
            // Sort by shortest dissolve delay
            let neurons = Array.sort(Iter.toArray(stakingNeurons.vals()), compareDissolveDelay);

            // Split as much as we can off each, until we are satisfied
            var remaining = e8s;
            let toSplit = Buffer.Buffer<(Nat64, Nat64)>(0);
            for (n in neurons.vals()) {
                // Filter out any we can't split (balance < 2icp+fee)
                if (remaining > 0 and n.cachedNeuronStakeE8s >= (minimumStake*2)+icpFee) {
                    let amountToSplit = Nat64.min(remaining, n.cachedNeuronStakeE8s - minimumStake - icpFee);
                    remaining -= amountToSplit;
                    toSplit.add((n.id, amountToSplit));
                };
            };

            // If we couldn't get enough, fail w insufficient liquidity
            if (remaining > 0) {
                return #err(#InsufficientStake);
            };

            // Do the splits and find the new neurons.
            let newNeurons = Buffer.Buffer<Neurons.Neuron>(toSplit.size());
            for ((id, amount) in toSplit.vals()) {
                switch (await args.neurons.split(id, amount+icpFee)) {
                    case (#err(err)) {
                        // TODO: Error handling
                    };
                    case (#ok(n)) {
                        newNeurons.add(n);
                    };
                };
            };
            return #ok(newNeurons.toArray());
        };

        public func preupgrade(): ?UpgradeData {
            return ?#v1({
                stakingNeurons = Iter.toArray(stakingNeurons.entries());
            });
        };

        public func postupgrade(upgradeData: ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
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

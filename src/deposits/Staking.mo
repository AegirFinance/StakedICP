import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
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

        // depositIcp takes an amount of e8s to deposit, and returns a list of
        // transfers to make.
        // TODO: Route incoming ICP to neurons based on existing balances
        public func depositIcp(e8s: Nat64, fromSubaccount: ?Account.Subaccount): [Ledger.TransferArgs] {
            if (e8s <= icpFee) {
                return [];
            };
            
            // For now just return the first neuron account for all of it.
            switch (stakingNeurons.vals().next()) {
                case (null) { [] };
                case (?neuron) {
                    let to = Blob.toArray(neuron.accountId);
                    [
                        {
                            memo : Nat64    = 0;
                            from_subaccount = Option.map(fromSubaccount, Blob.toArray);
                            to              = Blob.toArray(neuron.accountId);
                            amount          = { e8s = e8s - icpFee };
                            fee             = { e8s = icpFee };
                            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
                        }
                    ]
                };
            }
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

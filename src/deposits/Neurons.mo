import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Int64 "mo:base/Int64";
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

import NNS "./NNS";
import Governance "../nns-governance";
import Ledger "../nns-ledger";
import Metrics "../metrics/types";

module {
    // NNS constants
    let minimumStake: Nat64 = 100_000_000;
    let icpFee: Nat64 = 10_000;

    public type UpgradeData = {
        #v1: {
            governance: Principal;
            proposalNeuron: ?NeuronV1;
        };
        #v2;
    };

    // Neuron is the local state we store about a neuron.
    public type NeuronV1 = {
        id : Nat64;
        accountId : NNS.AccountIdentifier;
        dissolveState : ?Governance.DissolveState;
        cachedNeuronStakeE8s : Nat64;
    };

    public type Neuron = {
        id : Nat64;
        accountId : NNS.AccountIdentifier;
        dissolveState : ?Governance.DissolveState;
        cachedNeuronStakeE8s : Nat64;
        stakedMaturityE8sEquivalent: ?Nat64;
    };

    public type NeuronsError = {
        #ProposalNeuronMissing;
        #InsufficientMaturity;
        #Other: Text;
        #InsufficientStake;
        #GovernanceError: Governance.GovernanceError;
    };

    public func upgradeNeuronV1(n: NeuronV1): Neuron {
        {
            id = n.id;
            accountId = n.accountId;
            dissolveState = n.dissolveState;
            cachedNeuronStakeE8s = n.cachedNeuronStakeE8s;
            stakedMaturityE8sEquivalent = null;
        }
    };

    public type NeuronResult = Result.Result<Neuron, NeuronsError>;
    public type NeuronResultV1 = Result.Result<NeuronV1, NeuronsError>;
    public type NeuronsResult = Result.Result<[Neuron], NeuronsError>;
    public type Nat64Result = Result.Result<Nat64, NeuronsError>;

    // Find and normalize the dissolve delay for a neuron.
    public func dissolveDelay({dissolveState}: Neuron): Int {
        switch (dissolveState) {
            case (?#DissolveDelaySeconds(delay)) { Int64.toInt(Int64.fromNat64(delay)) };
            case (null) { 0 };
            case (?#WhenDissolvedTimestampSeconds(timestamp)) {
                let now = Time.now();
                let t = Int64.toInt(Int64.fromNat64(timestamp));
                if (t <= now) {
                    0
                } else {
                    t - now
                }
            };
        }
    };

    // Neuron management helpers.
    public class Manager(args: {
        governance: Principal;
    }) {
        private var governance: Governance.Interface = actor(Principal.toText(args.governance));

        public func metrics(): async [Metrics.Metric] {
            let ms = Buffer.Buffer<Metrics.Metric>(0);
            ms.toArray()
        };

        // ===== NEURON INFO FUNCTIONS =====

        // list fetches a bunch of neurons by ids (or all, if ids omitted)
        public func list(ids: ?[Nat64]): async [Neuron] {
            let response = await governance.list_neurons({
                neuron_ids = Option.get<[Nat64]>(ids, []);
                include_neurons_readable_by_caller = Option.isNull(ids);
            });
            let b = Buffer.Buffer<Neuron>(response.full_neurons.size());
            for (neuron in response.full_neurons.vals()) {
                switch (neuron.id) {
                    case (null) { };
                    case (?id) {
                        b.add({
                            id = id.id;
                            accountId = NNS.accountIdFromPrincipal(args.governance, Blob.fromArray(neuron.account));
                            dissolveState = neuron.dissolve_state;
                            cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                            stakedMaturityE8sEquivalent = neuron.staked_maturity_e8s_equivalent;
                        });
                    };
                };
            };
            b.toArray()
        };

        // Refresh a neuron's balance and info
        public func refresh(id: Nat64): async NeuronResult {
            try {
                // Update the cached balance in governance canister
                switch ((await governance.manage_neuron({
                    id = null;
                    command = ?#ClaimOrRefresh({ by = ?#NeuronIdOrSubaccount({}) });
                    neuron_id_or_subaccount = ?#NeuronId({ id = id });
                })).command) {
                    case (?#Error(err)) {
                        return #err(#GovernanceError(err));
                    };
                    case (_) {};
                };
                // Fetch and cache the new balance
                switch (await governance.get_full_neuron(id)) {
                    case (#Err(err)) {
                        return #err(#GovernanceError(err));
                    };
                    case (#Ok(neuron)) {
                        return #ok({
                            id = id;
                            accountId = NNS.accountIdFromPrincipal(args.governance, Blob.fromArray(neuron.account));
                            dissolveState = neuron.dissolve_state;
                            cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                            stakedMaturityE8sEquivalent = neuron.staked_maturity_e8s_equivalent;
                        });
                    };
                };
            } catch (error) {
                return #err(#Other(Error.message(error)));
            }
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade(): ?UpgradeData {
            return ?#v2;
        };

        public func postupgrade(upgradeData: ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    postupgrade(?#v2);
                };
                case (?#v2) {
                    // no-op
                    return;
                };
                case (_) { return; };
            };
        };
    }
}

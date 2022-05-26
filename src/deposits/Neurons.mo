import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import Account      "./Account";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";

module {
    let icpFee: Nat64 = 10_000;

    public type UpgradeData = {
        #v1: {
            governance: Principal;
            proposalNeuron: ?Neuron;
            stakingNeurons: [(Text, Neuron)];
        };
    };

    public type Metrics = {
    };

    public type Neuron = {
        id : Nat64;
        accountId : Account.AccountIdentifier;
        dissolveState : ?Governance.DissolveState;
        cachedNeuronStakeE8s : Nat64;
    };

    public type NeuronsError = {
        #StakingNeuronMissing;
        #ProposalNeuronMissing;
        #InsufficientMaturity;
        #Other: Text;
    };

    public type MergeMaturityResponse = {
        #Ok : ([(Nat, Governance.ManageNeuronResponse)]);
        #Err: NeuronsError;
    };

    public class Manager(args: {
        governance: Principal;
    }) {
        // 30 days
        private var second = 1_000_000_000;
        private var minute = 60*second;
        private var hour = 60*minute;
        private var day = 24*hour;

        private var governance: Governance.Interface = actor(Principal.toText(args.governance));
        private var proposalNeuron: ?Neuron = null;
        private var stakingNeurons = TrieMap.TrieMap<Text, Neuron>(Text.equal, Text.hash);

        public func metrics(): Metrics {
            return {};
        };

        public func getProposalNeuron(): ?Neuron {
            proposalNeuron
        };

        public func setProposalNeuron(id: Nat64): async ?Governance.GovernanceError {
            switch (await governance.get_full_neuron(id)) {
                case (#Err(err)) {
                    return ?err;
                };
                case (#Ok(neuron)) {
                    proposalNeuron := ?{
                        id = id;
                        accountId = Account.fromPrincipal(args.governance, Blob.fromArray(neuron.account));
                        dissolveState = neuron.dissolve_state;
                        cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                    };
                };
            };
            return null;
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

        public func ids(): [Nat64] {
            Iter.toArray(Iter.map(
                stakingNeurons.vals(),
                func (n: Neuron): Nat64 { n.id }
            ))
        };

        public func maturities(): async [(Nat64, Nat64)] {
            let response = await governance.list_neurons({
                neuron_ids = ids();
                include_neurons_readable_by_caller = true;
            });
            let b = Buffer.Buffer<(Nat64, Nat64)>(stakingNeurons.size());
            for (neuron in response.full_neurons.vals()) {
                let existing = Option.chain(
                    neuron.id,
                    func(id: Governance.NeuronId): ?Neuron {
                        stakingNeurons.get(Nat64.toText(id.id))
                    }
                );
                switch (existing) {
                    case (null) {};
                    case (?e) {
                        b.add((e.id, neuron.maturity_e8s_equivalent));
                    };
                };
            };
            return b.toArray()
        };

        // addOrRefresh idempotently adds a staking neuron, or refreshes it's balance
        public func addOrRefresh(id: Nat64): async ?Governance.GovernanceError {
                // Update the cached balance in governance canister
                switch ((await governance.manage_neuron({
                    id = null;
                    command = ?#ClaimOrRefresh({ by = ?#NeuronIdOrSubaccount({}) });
                    neuron_id_or_subaccount = ?#NeuronId({ id = id });
                })).command) {
                    case (?#Error(err)) {
                        return ?err;
                    };
                    case (_) {};
                };
                // Fetch and cache the new balance
                switch (await governance.get_full_neuron(id)) {
                    case (#Err(err)) {
                        return ?err;
                    };
                    case (#Ok(neuron)) {
                        stakingNeurons.put(Nat64.toText(id), {
                            id = id;
                            accountId = Account.fromPrincipal(args.governance, Blob.fromArray(neuron.account));
                            dissolveState = neuron.dissolve_state;
                            cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                        });
                    };
                };
                return null;
        };

        // TODO: How do we take our cut here?
        public func mergeMaturity(percentage: Nat32): async MergeMaturityResponse {
            switch (proposalNeuron) {
                case (null) {
                    return #Err(#ProposalNeuronMissing);
                };
                case (?proposalNeuron) {
                    // TODO: Parallelize these calls
                    let b = Buffer.Buffer<(Nat, Governance.ManageNeuronResponse)>(stakingNeurons.size());

                    for ((id, maturity) in (await maturities()).vals()) {
                        if (maturity > icpFee) {
                            let response = await governance.manage_neuron({
                                id = null;
                                command = ?#MakeProposal({
                                    url = "https://stakedicp.com";
                                    title = ?"Merge Maturity";
                                    action = ?#ManageNeuron({
                                        id = null;
                                        command = ?#MergeMaturity({
                                            percentage_to_merge = percentage
                                        });
                                        neuron_id_or_subaccount = ?#NeuronId({ id = id });
                                    });
                                    summary = "Merge Maturity";
                                });
                                neuron_id_or_subaccount = ?#NeuronId({ id = proposalNeuron.id });
                            });
                            b.add((Nat64.toNat(id), response));
                            // TODO: Check the proposals were successful
                            ignore await addOrRefresh(id)
                            // TODO: Handle error results here
                        };
                    };
                    return #Ok(b.toArray());
                };
            };
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

        public func split(id: Nat64, amount_e8s: Nat64): async ?Governance.ProposalInfo {
            do ? {
                let proposalNeuronId = (proposalNeuron !).id;
                let neuron = stakingNeurons.get(Nat64.toText(id)) !;

                let manageNeuronResponse = await governance.manage_neuron({
                    id = null;
                    command = ?#MakeProposal({
                        url = "https://stakedicp.com";
                        title = ?"Split Neuron";
                        action = ?#ManageNeuron({
                            id = null;
                            command = ?#Split({
                                amount_e8s = amount_e8s;
                            });
                            neuron_id_or_subaccount = ?#NeuronId({ id = id });
                        });
                        summary = "Split Neuron";
                    });
                    neuron_id_or_subaccount = ?#NeuronId({ id = proposalNeuronId });
                });

                let proposalId = switch (manageNeuronResponse.command !) {
                    case (#MakeProposal { proposal_id }) {
                        proposal_id !
                    };
                    case (_) { null ! };
                };

                (await governance.get_proposal_info(proposalId.id)) !
            }
        };

        public func preupgrade(): ?UpgradeData {
            return ?#v1({
                governance = args.governance;
                proposalNeuron = proposalNeuron;
                stakingNeurons = Iter.toArray(stakingNeurons.entries());
            });
        };

        public func postupgrade(upgradeData: ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    governance := actor(Principal.toText(args.governance));
                    proposalNeuron := data.proposalNeuron;
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

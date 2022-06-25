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

import Account      "./Account";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";

module {
    let minimumStake: Nat64 = 100_000_000;
    let icpFee: Nat64 = 10_000;

    public type UpgradeData = {
        #v1: {
            governance: Principal;
            proposalNeuron: ?Neuron;
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
        #ProposalNeuronMissing;
        #InsufficientMaturity;
        #Other: Text;
        #InsufficientStake;
        #GovernanceError: Governance.GovernanceError;
    };

    public type NeuronResult = Result.Result<Neuron, NeuronsError>;
    public type Nat64Result = Result.Result<Nat64, NeuronsError>;

    // Proposal-based neuron management. Let's our canister "directly" manage
    // NNS neurons. Used by other modules, like Withdrawals, and Staking.
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

        // Fetch maturity info for a list of neuron ids, as an array of [(id, e8s)].
        public func maturities(ids: [Nat64]): async [(Nat64, Nat64)] {
            let response = await governance.list_neurons({
                neuron_ids = ids;
                include_neurons_readable_by_caller = true;
            });
            let b = Buffer.Buffer<(Nat64, Nat64)>(response.full_neurons.size());
            for (neuron in response.full_neurons.vals()) {
                switch (neuron.id) {
                    case (null) { };
                    case (?id) {
                        b.add((id.id, neuron.maturity_e8s_equivalent));
                    };
                };
            };
            return b.toArray()
        };

        // Refresh a neuron's balance and info
        public func refresh(id: Nat64): async NeuronResult {
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
                            accountId = Account.fromPrincipal(args.governance, Blob.fromArray(neuron.account));
                            dissolveState = neuron.dissolve_state;
                            cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                        });
                    };
                };
        };

        public func mergeMaturity(id: Nat64, percentage: Nat32): async NeuronResult {
            let proposal = await propose({
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
            switch (proposal) {
                case (#err(err)) {
                    return #err(err);
                };
                case (#ok(_)) {
                    return await refresh(id);
                };
            };
        };

        public func mergeMaturities(ids: [Nat64], percentage: Nat32): async [NeuronResult] {
            // TODO: Parallelize these calls
            let b = Buffer.Buffer<NeuronResult>(ids.size());

            for ((id, maturity) in (await maturities(ids)).vals()) {
                if (maturity > icpFee) {
                    b.add(await mergeMaturity(id, percentage));
                    // TODO: Check the proposals were successful
                };
            };
            return b.toArray();
        };

        private func okOr<Ok, Error>(x : ?Ok, e : Error) : Result.Result<Ok, Error> {
            switch x {
                case (?x)   { #ok(x) };
                case (null) { #err(e) };
            }
        };

        private func propose(proposal: Governance.Proposal): async Result.Result<Governance.ProposalInfo, NeuronsError> {
            let proposalNeuronId: Nat64 = switch (proposalNeuron) {
                case (null) { return #err(#ProposalNeuronMissing); };
                case (?n) { n.id };
            };

            let manageNeuronResult = await governance.manage_neuron({
                id = null;
                command = ?#MakeProposal(proposal);
                neuron_id_or_subaccount = ?#NeuronId({ id = proposalNeuronId });
            });

            let proposalId = switch (manageNeuronResult.command) {
                case (?#MakeProposal { proposal_id = ?id }) {
                    id.id
                };
                case (_) {
                    return #err(#Other("Unexpected command response: " # debug_show(manageNeuronResult)));
                };
            };

            let proposalInfo = switch (await governance.get_proposal_info(proposalId)) {
                case (?p) { p };
                case (null) {
                    return #err(#Other("Proposal not found: " # debug_show(proposalId)));
                };
            };

            switch (proposalInfo.failure_reason) {
                case (null) { };
                case (?err) {
                    return #err(#GovernanceError(err));
                };
            };

            return #ok(proposalInfo);
        };

        public func split(id: Nat64, amount_e8s: Nat64): async NeuronResult {
            if (amount_e8s < minimumStake + icpFee) {
                return #err(#InsufficientStake)
            };

            let title = "Split Neuron" # Nat64.toText(id);
            let proposal = await propose({
                url = "https://stakedicp.com";
                title = ?title;
                action = ?#ManageNeuron({
                    id = null;
                    command = ?#Split({
                        amount_e8s = amount_e8s;
                    });
                    neuron_id_or_subaccount = ?#NeuronId({ id = id });
                });
                summary = title;
            });
            switch (proposal) {
                case (#err(err)) {
                    return #err(err);
                };
                case (#ok(p)) {
                    let result = await findNewNeuron(
                        p.executed_timestamp_seconds,
                        amount_e8s - icpFee
                    );
                    return okOr(result, #Other("Neuron not found, proposal: " # debug_show(p.id)));
                };
            };
        };

        private func findNewNeuron(createdTimestampSeconds: Nat64, stakeE8s: Nat64): async ?Neuron {
            let response = await governance.list_neurons({
                neuron_ids = [];
                include_neurons_readable_by_caller = true;
            });
            for (neuron in response.full_neurons.vals()) {
                if (neuron.cached_neuron_stake_e8s == stakeE8s and neuron.created_timestamp_seconds == createdTimestampSeconds) {
                    switch (neuron.id) {
                        case (?id) {
                            return ?{
                                id = id.id;
                                accountId = Account.fromPrincipal(args.governance, Blob.fromArray(neuron.account));
                                dissolveState = neuron.dissolve_state;
                                cachedNeuronStakeE8s = neuron.cached_neuron_stake_e8s;
                            };
                        };
                        case (_) { };
                    };
                };
            };
            return null;
        };

        // Start a neuron dissolving
        public func dissolve(id: Nat64): async NeuronResult {
            let title = "Start Dissolving Neuron" # Nat64.toText(id);
            let proposal = await propose({
                url = "https://stakedicp.com";
                title = ?title;
                action = ?#ManageNeuron({
                    id = null;
                    command = ?#Configure({
                        operation = ?#StartDissolving({});
                    });
                    neuron_id_or_subaccount = ?#NeuronId({ id = id });
                });
                summary = title;
            });
            switch (proposal) {
                case (#err(err)) {
                    return #err(err);
                };
                case (#ok(_)) {
                    return await refresh(id);
                };
            };
        };

        // Attempt to disburse a neuron
        public func disburse(id: Nat64, account: Account.AccountIdentifier): async Nat64Result {
            let neuron = await refresh(id);
            switch (neuron) {
                case (#err(err)) {
                    return #err(err);
                };
                case (#ok(neuron)) {
                    let title = "Disburse Neuron" # Nat64.toText(id);
                    let proposal = await propose({
                        url = "https://stakedicp.com";
                        title = ?title;
                        action = ?#ManageNeuron({
                            id = null;
                            command = ?#Disburse({
                                // TODO: Test this hash thing goes to the right account here
                                to_account = ?{ hash = Blob.toArray(account) };
                                amount = ?{ e8s = neuron.cachedNeuronStakeE8s };
                            });
                            neuron_id_or_subaccount = ?#NeuronId({ id = id });
                        });
                        summary = title;
                    });
                    switch (proposal) {
                        case (#err(err)) {
                            return #err(err);
                        };
                        case (#ok(_)) {
                            // TODO: Is the icpFee subtracted here?
                            return #ok(neuron.cachedNeuronStakeE8s - icpFee);
                        };
                    };
                };
            };
        };

        public func preupgrade(): ?UpgradeData {
            return ?#v1({
                governance = args.governance;
                proposalNeuron = proposalNeuron;
            });
        };

        public func postupgrade(upgradeData: ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    governance := actor(Principal.toText(args.governance));
                    proposalNeuron := data.proposalNeuron;
                };
                case (_) { return; };
            };
        };
    }
}

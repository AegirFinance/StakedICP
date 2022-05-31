import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import Account "./Account";
import Nanoid "./Nanoid";
import Neurons "./Neurons";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
import Token "../DIP20/motoko/src/token";

module {
    public type UpgradeData = {
        #v1: {
            withdrawals: [(Text, Withdrawal)];
        };
    };

    public type Metrics = {
        count: Nat64;
        totalE8s: Nat64;
        pendingE8s: Nat64;
        availableE8s: Nat64;
        disbursedE8s: Nat64;
        neuronsCount: Nat64;
        usersCount: Nat64;
    };

    type Withdrawal = {
        id: Text;
        principal: Principal;
        createdAt: Time.Time;
        expectedAt: Time.Time;
        total: Nat64;
        pending: Nat64;
        available: Nat64;
        disbursed: Nat64;
        neurons: [Neurons.Neuron];
    };

    type WithdrawalsError = {
        #InsufficientBalance;
        #InsufficientLiquidity;
        #Other: Text;
        #TokenError: {
            // Copied from Token.mo
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #AmountTooSmall;
        };
        #NeuronsError: Neurons.NeuronsError;
    };

    type WithdrawalResult = Result.Result<Withdrawal, WithdrawalsError>;
    type PayoutResult = Result.Result<[Ledger.TransferResult], WithdrawalsError>;

    public class Manager(args: {
        token: Principal;
        neurons: Neurons.Manager;
    }) {
        private let token: Token.Token = actor(Principal.toText(args.token));
        private var withdrawals = TrieMap.TrieMap<Text, Withdrawal>(Text.equal, Text.hash);
        private var withdrawalsByPrincipal = TrieMap.TrieMap<Principal, Buffer.Buffer<Text>>(Principal.equal, Principal.hash);

        public func count(): Nat {
            withdrawals.size()
        };

        public func metrics(): Metrics {
            var totalE8s: Nat64 = 0;
            var pendingE8s: Nat64 = 0;
            var availableE8s: Nat64 = 0;
            var disbursedE8s: Nat64 = 0;
            var neuronsCount: Nat64 = 0;
            for (w in withdrawals.vals()) {
                totalE8s += w.total;
                pendingE8s += w.pending;
                availableE8s += w.available;
                disbursedE8s += w.disbursed;
                neuronsCount += Nat64.fromNat(w.neurons.size());
            };

            return {
                count = Nat64.fromNat(withdrawals.size());
                totalE8s = totalE8s;
                pendingE8s = pendingE8s;
                availableE8s = availableE8s;
                disbursedE8s = disbursedE8s;
                neuronsCount = neuronsCount;
                usersCount = Nat64.fromNat(withdrawalsByPrincipal.size());
            };
        };

        // Returns array of delays (seconds) and the amount (e8s) becoming
        // available after that delay.
        // TODO: Implement this properly.
        public func availableLiquidityGraph(): [(Nat64, Nat64)] {
            var sum: Nat64 = 0;
            for ((_, amount) in args.neurons.balances().vals()) {
                sum += amount;
            };

            // 8 years in seconds, and sum
            return [(252_460_800, sum)];
        };

        // TODO: Implement this
        public func createWithdrawal(user: Principal, total: Nat64): async WithdrawalResult {
            let now = Time.now();

            // Mark cash as available for instant withdrawal, and reserve
            // let available: Nat64 = 0;

            // Is there enough available liquidity in the neurons?
            // Figure out the unstaking schedule

            // Burn the tokens from the user. This makes sure there is enough
            // balance for the user, avoiding re-entrancy.
            // let burn = token.burn(user,total);
            // switch (burn) {
            //     case (#Err(err)) {
            //         return #err(#TokenError(err));
            //     };
            //     case (#Ok(_)) { };
            // };

            // Store the withdrawal
            // let withdrawal: Withdrawal = {
            //     id = id;
            //     principal = user;
            //     createdAt = now;
            //     expectedAt: Time.Time;
            //     total = total;
            //     pending = total - available;
            //     available = available;
            //     disbursed = 0;
            //     neurons = neurons.toArray();
            // }
            // withdrawals.put(id, withdrawal);

            // Split off the new neurons and start them dissolving
            // let neurons = Buffer.Buffer<Neurons.Neuron>(0);
            // Save them onto the withdrawal
            // withdrawal.neurons = neurons.toArray();
            // withdrawals.put(id, withdrawal);

            return #err(#Other("createWithdrawal: Not Implemented"));
        };

        public func withdrawalsFor(user: Principal): [Withdrawal] {
            var sources = Buffer.Buffer<Withdrawal>(0);
            let ids = Option.get<Buffer.Buffer<Text>>(withdrawalsByPrincipal.get(user), Buffer.Buffer<Text>(0));
            for (id in ids.vals()) {
                switch (withdrawals.get(id)) {
                    case (null) { P.unreachable(); };
                    case (?w) {
                        sources.add(w);
                    };
                };
            };
            return sources.toArray();
        };

        // record a conversion event for this referred user
        public func disburse(user: Principal, total: Nat64, to: Account.AccountIdentifier): async PayoutResult {
            let now = Time.now();

            // Figure out where it is coming from
            var sources = Buffer.Buffer<Withdrawal>(0);
            var found: Nat64 = 0;
            let ids = Option.get<Buffer.Buffer<Text>>(withdrawalsByPrincipal.get(user), Buffer.Buffer<Text>(0));
            for (id in ids.vals()) {
                switch (withdrawals.get(id)) {
                    case (null) { P.unreachable(); };
                    case (?w) {
                        if (found < total and w.available > 0) {
                            sources.add(w);
                            found += w.available;
                        };
                    };
                };
            };

            // Check the user has this much available
            if (found < total) {
                return #err(#InsufficientBalance);
            };

            // TODO: Pay it out. Disburse the neuron(s)
            // TODO: Remove the neuron from the withdrawal.

            return #err(#Other("disburse: Not Implemented"));
        };

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                withdrawals = Iter.toArray(withdrawals.entries());
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    for ((id, withdrawal) in Iter.fromArray(data.withdrawals)) {
                        withdrawals.put(id, withdrawal);
                        let buf = Option.get<Buffer.Buffer<Text>>(
                            withdrawalsByPrincipal.get(withdrawal.principal),
                            Buffer.Buffer<Text>(1)
                        );
                        buf.add(id);
                        withdrawalsByPrincipal.put(withdrawal.principal, buf);
                    };

                };
                case (_) { return; };
            };
        };
    }
}

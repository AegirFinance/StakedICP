import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Order "mo:base/Order";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import Account "./Account";
import Neurons "./Neurons";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
import Metrics "../metrics/types";
import Token "../DIP20/motoko/src/token";

module {
    // Cost to transfer ICP on the ledger
    let icpFee: Nat64 = 10_000;

    public type UpgradeData = {
        #v1: {
            dissolving: [(Text, Neurons.Neuron)];
            withdrawals: [(Text, Withdrawal)];
        };
    };

    public type Withdrawal = {
        id: Text;
        user: Principal;
        createdAt: Time.Time;
        expectedAt: Time.Time;
        readyAt: ?Time.Time;
        disbursedAt: ?Time.Time;
        total: Nat64;
        pending: Nat64;
        available: Nat64;
        disbursed: Nat64;
    };

    public type TokenError = {
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

    public type WithdrawalsError = {
        #InsufficientBalance;
        #InsufficientLiquidity;
        #InvalidAddress;
        #Other: Text;
        #TokenError: TokenError;
        #NeuronsError: Neurons.NeuronsError;
        #TransferError: Ledger.TransferError;
    };

    public type PayoutResult = Result.Result<Ledger.BlockIndex, WithdrawalsError>;

    type WithdrawalQueueEntry = {
        id: Text;
        createdAt: Time.Time;
    };

    // Withdrawals manager creates and manages all pending deposits. It
    // fulfills pending deposits from new deposits and dissolved neurons.
    public class Manager(args: {
        token: Principal;
        ledger: Principal;
        neurons: Neurons.Manager;
    }) {
        let second : Int = 1_000_000_000;

        private let token: Token.Token = actor(Principal.toText(args.token));
        private let ledger: Ledger.Self = actor(Principal.toText(args.ledger));
        private var dissolving = TrieMap.TrieMap<Text, Neurons.Neuron>(Text.equal, Text.hash);
        private var withdrawals = TrieMap.TrieMap<Text, Withdrawal>(Text.equal, Text.hash);
        private var pendingWithdrawals = Deque.empty<WithdrawalQueueEntry>();
        private var withdrawalsByUser = TrieMap.TrieMap<Principal, Buffer.Buffer<Text>>(Principal.equal, Principal.hash);

        // Tell the main contract how much icp to keep on-hand for pending deposits.
        // TODO: Maybe precompute and cache this
        public func reservedIcp(): Nat64 {
            var sum: Nat64 = 0;
            for (w in withdrawals.vals()) {
                sum += w.available;
            };
            return sum;
        };

        // Calculate the total amount of ICP currently dissolving in the NNS.
        // TODO: Maybe precompute and cache this
        public func totalDissolving(): Nat64 {
            var sum: Nat64 = 0;
            for (n in dissolving.vals()) {
                sum += n.cachedNeuronStakeE8s;
            };
            return sum;
        };

        // Calculate the total amount of ICP currently pending for withdrawals.
        // TODO: Maybe precompute and cache this
        public func totalPending(): Nat64 {
            var sum: Nat64 = 0;
            for (w in withdrawals.vals()) {
                sum += w.pending;
            };
            return sum;
        };

        public func count(): Nat {
            withdrawals.size()
        };

        public func metrics(): [Metrics.Metric] {
            var totalCount: Nat = 0;
            var pendingCount: Nat = 0;
            var readyCount: Nat = 0;
            var disbursedCount: Nat = 0;
            var totalE8s: Nat64 = 0;
            var pendingE8s: Nat64 = 0;
            var availableE8s: Nat64 = 0;
            var disbursedE8s: Nat64 = 0;
            for (w in withdrawals.vals()) {
                totalCount += 1;
                switch (w.readyAt, w.disbursedAt) {
                    case (null, null) { pendingCount += 1 };
                    case (  ?_, null) { readyCount += 1 };
                    case (   _,   ?_) { disbursedCount += 1 };
                };

                totalE8s += w.total;
                pendingE8s += w.pending;
                availableE8s += w.available;
                disbursedE8s += w.disbursed;
            };

            let ms = Buffer.Buffer<Metrics.Metric>(9);
            ms.add({
                name = "withdrawals_count";
                t = "gauge";
                help = ?"number of withdrawals";
                labels = [("state", "total")];
                value = Nat.toText(totalCount);
            });
            ms.add({
                name = "withdrawals_count";
                t = "gauge";
                help = ?"number of withdrawals";
                labels = [("state", "pending")];
                value = Nat.toText(pendingCount);
            });
            ms.add({
                name = "withdrawals_count";
                t = "gauge";
                help = ?"number of withdrawals";
                labels = [("state", "ready")];
                value = Nat.toText(readyCount);
            });
            ms.add({
                name = "withdrawals_count";
                t = "gauge";
                help = ?"number of withdrawals";
                labels = [("state", "disbursed")];
                value = Nat.toText(disbursedCount);
            });
            ms.add({
                name = "withdrawals_users_count";
                t = "gauge";
                help = ?"number of users who have initiated a withdrawal";
                labels = [];
                value = Nat.toText(withdrawalsByUser.size());
            });
            ms.add({
                name = "withdrawals_e8s";
                t = "gauge";
                help = ?"e8s value in withdrawals by state";
                labels = [("state", "total")];
                value = Nat64.toText(totalE8s);
            });
            ms.add({
                name = "withdrawals_e8s";
                t = "gauge";
                help = ?"e8s value in withdrawals by state";
                labels = [("state", "pending")];
                value = Nat64.toText(pendingE8s);
            });
            ms.add({
                name = "withdrawals_e8s";
                t = "gauge";
                help = ?"e8s value in withdrawals by state";
                labels = [("state", "available")];
                value = Nat64.toText(availableE8s);
            });
            ms.add({
                name = "withdrawals_e8s";
                t = "gauge";
                help = ?"e8s value in withdrawals by state";
                labels = [("state", "disbursed")];
                value = Nat64.toText(disbursedE8s);
            });
            ms.toArray()
        };

        // List all dissolving withdrawal neurons.
        public func listNeurons(): [Neurons.Neuron] {
            Iter.toArray(dissolving.vals())
        };

        // Idempotently add a neuron which should be dissolved and used to fill
        // pending withdrawals.
        public func addNeurons(ns: [Neurons.Neuron]): [Neurons.Neuron] {
            for (n in ns.vals()) {
                dissolving.put(Nat64.toText(n.id), n);
            };
            ns
        };

        // Attempt to create a new withdrawal for the user. The full amount
        // starts as `pending`, and the `depositIcp` method applies new
        // deposits, cash, and dissolving ICP towards fulfilling pending
        // deposits.
        public func createWithdrawal(user: Principal, amount: Nat64, delay: Int): Withdrawal {
            let now = Time.now();
            let id = nextWithdrawalId(user);
            let withdrawal: Withdrawal = {
                id = id;
                user = user;
                createdAt = now;
                expectedAt = now + (delay * second);
                readyAt = null;
                disbursedAt = null;
                total = amount;
                pending = amount;
                available = 0;
                disbursed = 0;
            };
            withdrawals.put(id, withdrawal);
            pendingWithdrawals := Deque.pushBack(pendingWithdrawals, {id = id; createdAt = now});
            withdrawalsByUserAdd(withdrawal.user, id);

            return withdrawal;
        };

        private func nextWithdrawalId(user: Principal): Text {
            let count = Option.get<Buffer.Buffer<Text>>(
                withdrawalsByUser.get(user),
                Buffer.Buffer<Text>(0)
            ).size();
            Principal.toText(user) # "-" # Nat.toText(count+1)
        };

        private func withdrawalsByUserAdd(user: Principal, id: Text) {
            let buf = Option.get<Buffer.Buffer<Text>>(
                withdrawalsByUser.get(user),
                Buffer.Buffer<Text>(1)
            );
            buf.add(id);
            withdrawalsByUser.put(user, buf);
        };

        // List all withdrawals for a user.
        public func withdrawalsFor(user: Principal): [Withdrawal] {
            var sources = Buffer.Buffer<Withdrawal>(0);
            let ids = Option.get<Buffer.Buffer<Text>>(withdrawalsByUser.get(user), Buffer.Buffer<Text>(0));
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

        // Apply some "incoming" ICP towards paying off our pending
        // withdrawals. ICP should be incoming either from new deposits, or
        // newly disbursed neurons. Returns the amount consumed.
        public func depositIcp(amount: Nat64): Nat64 {
            let now = Time.now();
            var remaining = amount;
            while (remaining > 0) {
                switch (Deque.peekFront(pendingWithdrawals)) {
                    case (null) {
                        // No (more) pending withdrawals
                        return amount-remaining;
                    };
                    case (?{id}) {
                        switch (withdrawals.get(id)) {
                            case (null) { P.unreachable(); };
                            case (?w) {
                                let applied = Nat64.min(w.pending, remaining);
                                remaining -= applied;
                                if (w.pending == applied) {
                                    // This withdrawal is done
                                    switch (Deque.popFront(pendingWithdrawals)) {
                                        case (null) {};
                                        case (?(_, q)) {
                                            pendingWithdrawals := q;
                                        };
                                    };
                                };
                                let readyAt = if (w.pending == applied) {
                                    ?now;
                                } else {
                                    null
                                };
                                withdrawals.put(id, {
                                    id = id;
                                    user = w.user;
                                    createdAt = w.createdAt;
                                    expectedAt = w.expectedAt;
                                    readyAt = readyAt;
                                    disbursedAt = w.disbursedAt;
                                    total = w.total;
                                    pending = w.pending - applied;
                                    available = w.available + applied;
                                    disbursed = w.disbursed;
                                });
                            };
                        };
                    };
                };
            };
            return amount-remaining;
        };

        // For now, neurons must be disbursed manually. List the neurons with are ready to be disbursed.
        public func listNeuronsToDisburse(): [Neurons.Neuron] {
            let now = Time.now();

            let ns = Buffer.Buffer<Neurons.Neuron>(0);
            for (neuron in dissolving.vals()) {
                let isDissolved = switch (neuron.dissolveState) {
                    case (?#DissolveDelaySeconds(delay)) {
                        // If the delay was 0, we can disburse it.
                        delay == 0
                    };
                    case (null) {
                        // Equivalent to dissolved already. Disburse.
                        true
                    };
                    case (?#WhenDissolvedTimestampSeconds(timestamp)) {
                        // If the timestamp is in the past, we're dissolved.
                        Nat64.toNat(timestamp) <= now
                    };
                };

                if (isDissolved) {
                    ns.add(neuron);
                };
            };

            ns.toArray()
        };

        // Once a neuron has been manually disbursed, we can forget about it.
        public func removeDisbursedNeurons(ids: [Nat64]): [Neurons.Neuron] {
            let ns = Buffer.Buffer<Neurons.Neuron>(ids.size());
            for (id in ids.vals()) {
                let key = Nat64.toText(id);
                switch (dissolving.get(key)) {
                    case (null) {};
                    case (?n) {
                        ns.add(n);
                        dissolving.delete(key);
                    };
                }
            };
            ns.toArray()
        };

        // Users call this to transfer their unlocked ICP in completed
        // withdrawals to an address of their choosing.
        public func completeWithdrawal(user: Principal, amount: Nat64, to: Account.AccountIdentifier): Result.Result<(Ledger.TransferArgs, () -> ()), WithdrawalsError> {
            let now = Time.now();

            // Figure out which available withdrawals we're disbursing
            var remaining : Nat64 = amount;
            var b = Buffer.Buffer<(Withdrawal, Nat64)>(1);
            for (w in withdrawalsFor(user).vals()) {
                if (remaining > 0 and w.available > 0) {
                    let applied = Nat64.min(w.available, remaining);
                    b.add((w, applied));
                    remaining -= applied;
                };
            };
            // Check the user has enough available
            if (remaining > 0) {
                return #err(#InsufficientBalance);
            };

            // TODO: Make sure you can't spam this to trigger race condition
            // for infinite withdrawal.

            // Update these withdrawal balances.
            for ((w, applied) in b.vals()) {
                let disbursedAt = if (w.disbursed + applied == w.total) {
                    ?now
                } else {
                    null
                };
                withdrawals.put(w.id, {
                        id = w.id;
                        user = w.user;
                        createdAt = w.createdAt;
                        expectedAt = w.expectedAt;
                        readyAt = w.readyAt;
                        disbursedAt = disbursedAt;
                        total = w.total;
                        pending = w.pending;
                        available = w.available - applied;
                        disbursed = w.disbursed + applied;
                        });
            };

            #ok((
                {
                    memo : Nat64    = 0;
                    from_subaccount = null;
                    to              = Blob.toArray(to);
                    amount          = { e8s = amount - icpFee };
                    fee             = { e8s = icpFee };
                    created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(now)) };
                },
                // Prepare a reversion in case the transfer fails
                func() {
                    for (({id}, applied) in b.vals()) {
                        let w = switch (withdrawals.get(id)) {
                            case (null) { P.unreachable() };
                            case (?w) { w };
                        };
                        withdrawals.put(w.id, {
                            id = w.id;
                            user = w.user;
                            createdAt = w.createdAt;
                            expectedAt = w.expectedAt;
                            readyAt = w.readyAt;
                            disbursedAt = null;
                            total = w.total;
                            pending = w.pending;
                            available = w.available + applied;
                            disbursed = w.disbursed - applied;
                        });
                    };
                }
            ))
        };

        public func ids(): [Nat64] {
            Iter.toArray(Iter.map(
                dissolving.vals(),
                func (n: Neurons.Neuron): Nat64 { n.id }
            ))
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                dissolving = Iter.toArray(dissolving.entries());
                withdrawals = Iter.toArray(withdrawals.entries());
            });
        };

        private func compareCreatedAt((_, a) : (Text, Withdrawal), (_, b) : (Text, Withdrawal)): Order.Order {
            Int.compare(a.createdAt, b.createdAt)
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    for ((id, neuron) in Iter.fromArray(data.dissolving)) {
                        dissolving.put(id, neuron);
                    };

                    for ((id, withdrawal) in Iter.fromArray(Array.sort(data.withdrawals, compareCreatedAt))) {
                        withdrawals.put(id, withdrawal);

                        if (withdrawal.pending > 0) {
                            pendingWithdrawals := Deque.pushBack(pendingWithdrawals, {
                                id = id;
                                createdAt = withdrawal.createdAt;
                            });
                        };

                        withdrawalsByUserAdd(withdrawal.user, id);
                    };
                };
                case (_) { return; };
            };
        };
    }
}

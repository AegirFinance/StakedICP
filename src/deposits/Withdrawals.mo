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
import Nanoid "./Nanoid";
import Neurons "./Neurons";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
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

    public type Metrics = {
        count: Nat64;
        totalE8s: Nat64;
        pendingE8s: Nat64;
        availableE8s: Nat64;
        disbursedE8s: Nat64;
        usersCount: Nat64;
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

    type TokenError = {
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

    type WithdrawalsError = {
        #InsufficientBalance;
        #InsufficientLiquidity;
        #InvalidAddress;
        #Other: Text;
        #TokenError: TokenError;
        #NeuronsError: Neurons.NeuronsError;
        #TransferError: Ledger.TransferError;
    };

    public type WithdrawalResult = Result.Result<Withdrawal, WithdrawalsError>;
    public type PayoutResult = Result.Result<Ledger.BlockIndex, WithdrawalsError>;

    type WithdrawalHeapEntry = {
        id: Text;
        createdAt: Time.Time;
    };

    // func heapToArray<T>(root: Heap.Heap<T>): [T] {
    //     var q = Deque.pushBack(Deque.empty<Heap.Tree<T>>(), root.share());
    //     var b = Buffer.Buffer<T>(1);
    //     for {
    //         switch (q.popFront()) {
    //             case (null) {};
    //             case (?(_, x, l, r)) {
    //                 b.add(x);
    //                 q := Deque.pushBack(q, l);
    //                 q := Deque.pushBack(q, r);
    //             };
    //         };
    //     };
    //     b.toArray()
    // };

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
        private var pendingWithdrawals = Deque.empty<WithdrawalHeapEntry>();
        private var withdrawalsByUser = TrieMap.TrieMap<Principal, Buffer.Buffer<Text>>(Principal.equal, Principal.hash);

        // Tell the main contract how much icp to keep on-hand
        // TODO: Maybe precompute and cache this
        public func reservedIcp(): Nat64 {
            var sum: Nat64 = 0;
            for (w in withdrawals.vals()) {
                sum += w.available;
            };
            return sum;
        };

        // TODO: Maybe precompute and cache this
        public func totalDissolving(): Nat64 {
            var sum: Nat64 = 0;
            for (n in dissolving.vals()) {
                sum += n.cachedNeuronStakeE8s;
            };
            return sum;
        };

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

        public func metrics(): Metrics {
            var totalE8s: Nat64 = 0;
            var pendingE8s: Nat64 = 0;
            var availableE8s: Nat64 = 0;
            var disbursedE8s: Nat64 = 0;
            for (w in withdrawals.vals()) {
                totalE8s += w.total;
                pendingE8s += w.pending;
                availableE8s += w.available;
                disbursedE8s += w.disbursed;
            };

            return {
                count = Nat64.fromNat(withdrawals.size());
                totalE8s = totalE8s;
                pendingE8s = pendingE8s;
                availableE8s = availableE8s;
                disbursedE8s = disbursedE8s;
                usersCount = Nat64.fromNat(withdrawalsByUser.size());
            };
        };

        public func addNeurons(ns: [Neurons.Neuron]): async Result.Result<[Neurons.Neuron], Neurons.NeuronsError> {
            let newNeurons = Buffer.Buffer<Neurons.Neuron>(ns.size());
            for (n in ns.vals()) {
                let key = Nat64.toText(n.id);
                if (dissolving.get(key) == null) {
                    let neuron = switch (n.dissolveState) {
                        case (?#DissolveDelaySeconds(delay)) {
                            // Make sure the neuron is dissolving
                            switch (await args.neurons.dissolve(n.id)) {
                                case (#err(err)) {
                                    return #err(err);
                                };
                                case (#ok(n)) {
                                    n
                                };
                            }
                        };
                        case (_) { n };
                    };
                    newNeurons.add(neuron);
                    dissolving.put(key, neuron);
                }
            };
            #ok(newNeurons.toArray())
        };

        public func createWithdrawal(user: Principal, amount: Nat64, availableCash: Nat64, delay: Int): async WithdrawalResult {
            let now = Time.now();

            // Mark cash as available for instant withdrawal
            let available: Nat64 = Nat64.min(availableCash, amount);

            // Burn the tokens from the user. This makes sure there is enough
            // balance for the user, avoiding re-entrancy.
            let burn = await token.burnFor(user, Nat64.toNat(amount));
            switch (burn) {
                case (#Err(err)) {
                    return #err(#TokenError(err));
                };
                case (#Ok(_)) { };
            };

            // TODO: Re-check we have enough cash+neurons, to avoid re-entrancy or timing attacks

            // Store the withdrawal
            let readyAt = if (delay == 0) {
                ?now
            } else {
                null
            };
            var id = await Nanoid.new();
            while (Option.isSome(withdrawals.get(id))) {
                // Re-generate if there's a collision.
                id := await Nanoid.new();
            };
            let withdrawal: Withdrawal = {
                id = id;
                user = user;
                createdAt = now;
                expectedAt = now + (delay * second);
                readyAt = readyAt;
                disbursedAt = null;
                total = amount;
                pending = amount - available;
                available = available;
                disbursed = 0;
            };
            withdrawals.put(id, withdrawal);
            if (available < amount) {
                pendingWithdrawals := Deque.pushBack(pendingWithdrawals, {id = id; createdAt = now});
            };
            withdrawalsByUserAdd(withdrawal.user, id);

            return #ok(withdrawal);
        };

        private func withdrawalsByUserAdd(user: Principal, id: Text) {
            let buf = Option.get<Buffer.Buffer<Text>>(
                withdrawalsByUser.get(user),
                Buffer.Buffer<Text>(1)
            );
            buf.add(id);
            withdrawalsByUser.put(user, buf);
        };

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

        // Apply some ICP towards paying off our deposits balance. Either from
        // new deposits, or newly disbursed neurons. Returns the amount consumed.
        public func applyIcp(amount: Nat64): Nat64 {
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

        // Disburse and/or create dissolving neurons such that account will receive (now or later) amount_e8s.
        // TODO: Merge maturity on any dissolving neurons which have pending maturity.
        // TODO: Call this in the heartbeat function
        public func disburseNeurons(account_id : Account.AccountIdentifier): async Neurons.Nat64Result {
            let now = Time.now();

            var disbursed: Nat64 = 0;
            for (neuron in dissolving.vals()) {
                let isDissolved = switch (neuron.dissolveState) {
                    case (?#DissolveDelaySeconds(delay)) {
                        // Not dissolving. start it. This shouldn't happen,
                        // because we should start the neurons dissolving when
                        // we first split them, but just in case, this will
                        // recover.
                        switch (await args.neurons.dissolve(neuron.id)) {
                            case (#err(err)) {
                                return #err(err);
                            };
                            case (#ok(n)) {
                                dissolving.put(Nat64.toText(neuron.id), n);
                            };
                        };
                        // If the delay was 0, it'll dissolve immediately, so
                        // we can disburse it.
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
                    switch (await args.neurons.disburse(neuron.id, account_id)) {
                        case (#err(err)) {
                            return #err(err);
                        };
                        case (#ok(amount)) {
                            disbursed += amount;
                            dissolving.delete(Nat64.toText(neuron.id));
                        };
                    };
                };
            };

            return #ok(disbursed);
        };


        // Transfer unlocked ICP in complete withdrawals to an address
        public func disburse(user: Principal, amount: Nat64, to: Account.AccountIdentifier): async PayoutResult {
            let now = Time.now();

            // Figure out which available withdrawals we're disbursing
            var remaining : Nat64 = amount;
            var b = Buffer.Buffer<(Nat64, Withdrawal)>(1);
            for (w in withdrawalsFor(user).vals()) {
                if (remaining > 0 and w.pending == 0 and w.available > 0) {
                    let applied = Nat64.min(w.available, remaining);
                    b.add((applied, w));
                    remaining -= applied;
                };
            };
            // Check the user has enough available
            if (remaining > 0) {
                return #err(#InsufficientBalance);
            };

            // TODO: Make sure you can't spam this to trigger race condition
            // for infinite withdrawal.

            let transfer = await ledger.transfer({
                    memo : Nat64    = 0;
                    from_subaccount = null;
                    to              = Blob.toArray(to);
                    amount          = { e8s = amount - icpFee };
                    fee             = { e8s = icpFee };
                    created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(now)) };
            });
            switch (transfer) {
                case (#Ok(block)) {
                    // Mark these withdrawals as disbursed.
                    for ((applied, w) in b.vals()) {
                        // TODO: Check this updates them in the original array
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
                    #ok(block)
                };
                case (#Err(#InsufficientFunds{})) {
                    // Not enough ICP in the contract
                    #err(#InsufficientLiquidity)
                };
                case (#Err(err)) {
                    #err(#TransferError(err))
                };
            }
        };

        public func ids(): [Nat64] {
            Iter.toArray(Iter.map(
                dissolving.vals(),
                func (n: Neurons.Neuron): Nat64 { n.id }
            ))
        };

        public func mergeMaturity(): async [Neurons.NeuronResult] {
            let merges = await args.neurons.mergeMaturities(ids(), 100);
            for (m in merges.vals()) {
                switch (m) {
                    case (#err(err)) { };
                    case (#ok(neuron)) {
                        dissolving.put(Nat64.toText(neuron.id), neuron);
                    };
                };
            };
            merges
        };

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

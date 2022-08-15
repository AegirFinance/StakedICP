import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
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

import Neurons "./Neurons";
import Referrals "./Referrals";
import Staking "./Staking";
import Withdrawals "./Withdrawals";
import Ledger "../ledger/Ledger";
import Token "../DIP20/motoko/src/token";

module {
    public type UpgradeData = {
        #v1: {
            apply: ?Result.Result<ApplyInterestResult, Neurons.NeuronsError>;
            flush: ?[Ledger.TransferResult];
            merge: ?[Neurons.Neuron];
            split: ?Result.Result<[Neurons.Neuron], Neurons.NeuronsError>;
            error: ?Neurons.NeuronsError;
            snapshot: ?[(Principal, Nat)];
            appliedInterest: [ApplyInterestResult];
            meanAprMicrobips: Nat64;
        };
    };

    public type ApplyInterestResult = {
        timestamp : Time.Time;
        supply : {
            before : Ledger.Tokens;
            after : Ledger.Tokens;
        };
        applied : Ledger.Tokens;
        remainder : Ledger.Tokens;
        totalHolders: Nat;
        affiliatePayouts: Nat;
    };

    public type QueueMintFn = (to: Principal, amount: Nat64) -> Nat64;
    public type AvailableBalanceFn = () -> Nat64;
    public type RefreshAvailableBalanceFn = () -> async Nat64;

    // Job is the state machine that manages the daily
    // merging/splitting/interest.
    public class Job(args: {
        ledger: Ledger.Self;
        neurons: Neurons.Manager;
        referralTracker: Referrals.Tracker;
        staking: Staking.Manager;
        token: Token.Token;
        withdrawals: Withdrawals.Manager;
    }) {
        // Makes date math simpler
        let second : Int = 1_000_000_000;
        let minute : Int = 60 * second;
        let hour : Int = 60 * minute;
        let day : Int = 24 * hour;

        // For apr calcs
        let microbips : Nat64 = 100_000_000;

        // State for an individual job run
        private var apply: ?Result.Result<ApplyInterestResult, Neurons.NeuronsError> = null;
        private var flush: ?[Ledger.TransferResult] = null;
        private var merge: ?[Neurons.Neuron] = null;
        private var split: ?Result.Result<[Neurons.Neuron], Neurons.NeuronsError> = null;
        private var error: ?Neurons.NeuronsError = null;

        // State used across job runs
        private var snapshot : ?[(Principal, Nat)] = null;
        private var appliedInterest : Buffer.Buffer<ApplyInterestResult> = Buffer.Buffer(0);
        private var meanAprMicrobips : Nat64 = 0;

        // ===== GETTER/SETTER FUNCTIONS =====

        public func setInitialSnapshot(): async (Text, [(Principal, Nat)]) {
            switch (snapshot) {
                case (null) {
                    let holders = await getAllHolders();
                    snapshot := ?holders;
                    return ("new", holders);
                };
                case (?holders) {
                    return ("existing", holders);
                };
            };
        };

        // ===== JOB START FUNCTION =====

        public func start(
            now: Time.Time,
            root: Principal,
            queueMint: QueueMintFn,
            availableBalance: AvailableBalanceFn,
            refreshAvailableBalance: RefreshAvailableBalanceFn
        ) : async () {
            apply := null;
            flush := null;
            merge := null;
            split := null;
            error := null;

            // Can run these three in "parallel"
            // TODO: These functions need to update the state
            ignore applyInterest(now, root, queueMint);
            ignore flushPendingDeposits(availableBalance, refreshAvailableBalance);
            ignore mergeWithdrawalMaturity();
        };

        // If we're done with the apply/flush/merge, move onto the split
        private func splitIfReady(): async () {
            if (error != null) {
                return;
            };
            if (apply == null or flush == null or merge == null) {
                return;
            };
            ignore splitNewWithdrawalNeurons();
        };

        // Merge the interest
        private func applyInterest(now: Time.Time, root: Principal, queueMint: QueueMintFn) : async () {
            apply := ?(await _applyInterest(now, root, queueMint));
            ignore splitIfReady();
        };

        // Flush pending deposits
        private func flushPendingDeposits(
            availableBalance: AvailableBalanceFn,
            refreshAvailableBalance: RefreshAvailableBalanceFn
        ) : async () {
            flush := ?(await _flushPendingDeposits(availableBalance, refreshAvailableBalance));
            ignore splitIfReady();
        };

        // merge the maturity for our dissolving withdrawal neurons
        private func mergeWithdrawalMaturity() : async () {
            merge := ?(await _mergeWithdrawalMaturity());
            ignore splitIfReady();
        };

        // Split off as many staking neurons as we need to ensure withdrawals
        // will be satisfied.
        //
        // Note: This needs to happen *after* everything above, hence the awaits.
        private func splitNewWithdrawalNeurons() : async () {
            split := ?(await _splitNewWithdrawalNeurons());
        };

        // ===== WORKER FUNCTIONS =====

        // Distribute newly earned interest to token holders.
        private func _applyInterest(now: Time.Time, root: Principal, queueMint: QueueMintFn) : async Result.Result<ApplyInterestResult, Neurons.NeuronsError> {
            // take a snapshot of the holders for tomorrow's interest.
            let nextHolders = await getAllHolders();

            // See how much maturity we have pending
            let interest = await stakingNeuronMaturityE8s();
            if (interest <= 10_000) {
                return #err(#InsufficientMaturity);
            };

            // Note: We might "leak" a tiny bit of interest here because maturity
            // could increase before we merge. It would be ideal if the NNS allowed
            // specify maturity to merge as an e8s, but alas.
            let merges = await mergeMaturities(args.staking.ids(), 100);
            for (n in merges.vals()) {
                ignore args.staking.addOrRefresh(n);
            };

            // Apply the interest to the holders
            let apply = applyInterestToToken(
                now,
                Nat64.toNat(interest),
                Option.get(snapshot, nextHolders),
                root,
                queueMint
            );

            // Update the snapshot for next time.
            snapshot := ?nextHolders;

            // Update the APY calculation
            appliedInterest.add(apply);
            appliedInterest := sortBuffer(appliedInterest, sortInterestByTime);
            updateMeanAprMicrobips();

            #ok(apply)
        };

        private func applyInterestToToken(now: Time.Time, interest: Nat, holders: [(Principal, Nat)], root: Principal, queueMint: QueueMintFn): ApplyInterestResult {
            // Calculate everything
            var beforeSupply : Nat = 0;
            for (i in Iter.range(0, holders.size() - 1)) {
                let (_, balance) = holders[i];
                beforeSupply += balance;
            };

            if (interest == 0) {
                return {
                    timestamp = now;
                    supply = {
                        before = { e8s = Nat64.fromNat(beforeSupply) };
                        after = { e8s = Nat64.fromNat(beforeSupply) };
                    };
                    applied = { e8s = 0 : Nat64 };
                    remainder = { e8s = 0 : Nat64 };
                    totalHolders = holders.size();
                    affiliatePayouts = 0;
                };
            };

            var holdersPortion = (interest * 9) / 10;
            var remainder = interest;

            // Calculate the holders portions
            var mints = Buffer.Buffer<(Principal, Nat)>(holders.size());
            var applied : Nat = 0;
            for (i in Iter.range(0, holders.size() - 1)) {
                let (to, balance) = holders[i];
                let share = (holdersPortion * balance) / beforeSupply;
                if (share > 0) {
                    mints.add((to, share));
                };
                assert(share <= remainder);
                remainder -= share;
                applied += share;
            };
            assert(applied + remainder == interest);
            assert(holdersPortion >= remainder);

            // Queue the mints & affiliate payouts
            var affiliatePayouts : Nat = 0;
            for ((to, share) in mints.vals()) {
                Debug.print("interest: " # debug_show(share) # " to " # debug_show(to));
                ignore queueMint(to, Nat64.fromNat(share));
                switch (args.referralTracker.payout(to, share)) {
                    case (null) {};
                    case (?(affiliate, payout)) {
                        Debug.print("affiliate: " # debug_show(payout) # " to " # debug_show(affiliate));
                        ignore queueMint(affiliate, Nat64.fromNat(payout));
                        affiliatePayouts := affiliatePayouts + payout;
                        assert(payout <= remainder);
                        remainder -= payout;
                    };
                }
            };

            // Deal with our share. For now, just mint it to this canister.
            if (remainder > 0) {
                Debug.print("remainder: " # debug_show(remainder) # " to " # debug_show(root));
                ignore queueMint(root, Nat64.fromNat(remainder));
                applied += remainder;
                remainder := 0;
            };

            // Check everything matches up
            assert(applied+affiliatePayouts+remainder == interest);

            return {
                timestamp = now;
                supply = {
                    before = { e8s = Nat64.fromNat(beforeSupply) };
                    after = { e8s = Nat64.fromNat(beforeSupply+applied+affiliatePayouts) };
                };
                applied = { e8s = Nat64.fromNat(applied) };
                remainder = { e8s = Nat64.fromNat(remainder) };
                totalHolders = holders.size();
                affiliatePayouts = affiliatePayouts;
            };
        };

        // Recalculate and update the cached mean interest for the last 7 days.
        //
        // 1 microbip is 0.000000001%
        // convert the result to apy % with:
        // (((1+(aprMicrobips / 100_000_000))^365.25) - 1)*100
        // e.g. 53900 microbips = 21.75% APY
        private func updateMeanAprMicrobips() {
            meanAprMicrobips := 0;

            if (appliedInterest.size() == 0) {
                return;
            };

            let last = appliedInterest.get(appliedInterest.size() - 1);

            // supply.before should always be > 0, because initial supply is 1, but...
            assert(last.supply.before.e8s > 0);

            // 7 days from the last time we applied interest, truncated to the utc Day start.
            let start = ((last.timestamp - (day * 6)) / day) * day;

            // sum all interest applications that are in that period.
            var i : Nat = appliedInterest.size();
            var sum : Nat64 = 0;
            var earliest : Time.Time  = last.timestamp;
            label range while (i > 0) {
                i := i - 1;
                let interest = appliedInterest.get(i);
                if (interest.timestamp < start) {
                    break range;
                };
                let after = interest.applied.e8s + Nat64.fromNat(interest.affiliatePayouts) + interest.remainder.e8s + interest.supply.before.e8s;
                sum := sum + ((microbips * after) / interest.supply.before.e8s) - microbips;
                earliest := interest.timestamp;
            };
            // truncate to start of first day where we found an application.
            // (in case we didn't have 7 days of applications)
            earliest := (earliest / day) * day;
            // end of last day
            let latest = ((last.timestamp / day) * day) + day;
            // Find the number of days we've spanned
            let span = Nat64.fromNat(Int.abs((latest - earliest) / day));

            // Find the mean
            meanAprMicrobips := sum / span;

            Debug.print("meanAprMicrobips: " # debug_show(meanAprMicrobips));
        };

        // Use new incoming deposits to attempt to rebalance the buckets, where
        // "the buckets" are:
        // - pending withdrawals
        // - ICP in the canister
        // - staking neurons
        private func _flushPendingDeposits(
            availableBalance: AvailableBalanceFn,
            refreshAvailableBalance: RefreshAvailableBalanceFn
        ): async [Ledger.TransferResult] {
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


        // Merge maturity on dissolving neurons. Merged maturity here will be
        // disbursed when the neuron is dissolved, and will be a "bonus" put
        // towards filling pending withdrawals early.
        private func _mergeWithdrawalMaturity() : async [Neurons.Neuron] {
            args.withdrawals.addNeurons(
                await mergeMaturities(args.withdrawals.ids(), 100)
            )
        };

        // Split off as many staking neurons as we need to satisfy pending withdrawals.
        private func _splitNewWithdrawalNeurons() : async Result.Result<[Neurons.Neuron], Neurons.NeuronsError> {
            // figure out how much we have dissolving for withdrawals
            let dissolving = args.withdrawals.totalDissolving();
            let pending = args.withdrawals.totalPending();

            // Split and dissolve enough new neurons to satisfy pending withdrawals
            if (pending <= dissolving) {
                return #ok([]);
            };
            // figure out how much we need dissolving for withdrawals
            let needed = pending - dissolving;
            // Split the difference off from staking neurons
            switch (args.staking.splitNeurons(needed)) {
                case (#err(err)) {
                    #err(err)
                };
                case (#ok(toSplit)) {
                    // Do the splits on the nns and find the new neurons.
                    let newNeurons = Buffer.Buffer<Neurons.Neuron>(toSplit.size());
                    for ((id, amount) in toSplit.vals()) {
                        switch (await args.neurons.split(id, amount)) {
                            case (#err(err)) {
                                // TODO: Error handling
                            };
                            case (#ok(n)) {
                                newNeurons.add(n);
                            };
                        };
                    };
                    // Pass the new neurons into the withdrawals manager.
                    switch (await dissolveNeurons(newNeurons.toArray())) {
                        case (#err(err)) { #err(err) };
                        case (#ok(newNeurons)) { #ok(args.withdrawals.addNeurons(newNeurons)) };
                    }
                };
            }
        };

        private func dissolveNeurons(ns: [Neurons.Neuron]): async Neurons.NeuronsResult {
            let newNeurons = Buffer.Buffer<Neurons.Neuron>(ns.size());
            for (n in ns.vals()) {
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
            };
            #ok(newNeurons.toArray())
        };

        // ===== HELPER FUNCTIONS =====

        // helper to short ApplyInterestResults
        private func sortInterestByTime(a: ApplyInterestResult, b: ApplyInterestResult): Order.Order {
            Int.compare(a.timestamp, b.timestamp)
        };

        // Buffers don't have sort, implement it ourselves.
        private func sortBuffer<A>(buf: Buffer.Buffer<A>, cmp: (A, A) -> Order.Order): Buffer.Buffer<A> {
            let result = Buffer.Buffer<A>(buf.size());
            for (x in Array.sort(buf.toArray(), cmp).vals()) {
                result.add(x);
            };
            result
        };

        private func getAllHolders(): async [(Principal, Nat)] {
            let info = await args.token.getTokenInfo();
            // *2 here is because this is not atomic, so if anyone joins in the
            // meantime.
            return await args.token.getHolders(0, info.holderNumber*2);
        };

        private func mergeMaturities(ids: [Nat64], percentage: Nat32): async [Neurons.Neuron] {
            Array.mapFilter<Result.Result<Neurons.Neuron, Neurons.NeuronsError>, Neurons.Neuron>(
                await args.neurons.mergeMaturities(args.withdrawals.ids(), percentage),
                func(r) { Result.toOption(r) },
            )
        };

        private func stakingNeuronMaturityE8s() : async Nat64 {
            let maturities = await args.neurons.maturities(args.staking.ids());
            var sum : Nat64 = 0;
            for ((id, maturities) in maturities.vals()) {
                sum += maturities;
            };
            sum
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                apply = apply;
                flush = flush;
                merge = merge;
                split = split;
                error = error;
                snapshot = snapshot;
                appliedInterest = appliedInterest.toArray();
                meanAprMicrobips = meanAprMicrobips;
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    apply := data.apply;
                    flush := data.flush;
                    merge := data.merge;
                    split := data.split;
                    error := data.error;
                    snapshot := data.snapshot;
                    appliedInterest := Buffer.Buffer<ApplyInterestResult>(data.appliedInterest.size());
                    for (x in data.appliedInterest.vals()) {
                        appliedInterest.add(x);
                    };
                    meanAprMicrobips := data.meanAprMicrobips;
                };
                case (_) { return; }
            };
        };
    };
};

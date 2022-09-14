import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
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

import Neurons "../Neurons";
import Referrals "../Referrals";
import Staking "../Staking";
import Ledger "../../ledger/Ledger";
import Token "../../DIP20/motoko/src/token";

module {
    public type UpgradeData = {
        #v1: {
            snapshot: ?[(Principal, Nat)];
            appliedInterest: [ApplyInterestSummary];
            meanAprMicrobips: Nat64;
        };
    };

    public type ApplyInterestResult = Result.Result<ApplyInterestSummary, Neurons.NeuronsError>;

    public type ApplyInterestSummary = {
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

    // Job is step of the daily process which merges and distributes interest
    // to holders.
    public class Job(args: {
        neurons: Neurons.Manager;
        referralTracker: Referrals.Tracker;
        staking: Staking.Manager;
        token: Token.Token;
    }) {
        // Makes date math simpler
        let second : Int = 1_000_000_000;
        let minute : Int = 60 * second;
        let hour : Int = 60 * minute;
        let day : Int = 24 * hour;

        // For apr calcs
        let microbips : Nat64 = 100_000_000;

        // State used across job runs
        private var snapshot : ?[(Principal, Nat)] = null;
        private var appliedInterest : Buffer.Buffer<ApplyInterestSummary> = Buffer.Buffer(0);
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

        public func getAppliedInterest(): [ApplyInterestSummary] {
            return appliedInterest.toArray();
        };

        public func setAppliedInterest(elems: [ApplyInterestSummary]) {
            appliedInterest := Buffer.Buffer<ApplyInterestSummary>(elems.size());
            for (x in elems.vals()) {
                appliedInterest.add(x);
            };
            updateMeanAprMicrobips();
        };

        public func getMeanAprMicrobips() : Nat64 {
            return meanAprMicrobips;
        };

        // ===== JOB START FUNCTION =====

        // Distribute newly earned interest to token holders.
        public func run(now: Time.Time, root: Principal, queueMint: QueueMintFn): async ApplyInterestResult {
            // take a snapshot of the holders for tomorrow's interest.
            let nextHolders = await getAllHolders();

            // TODO: Should we refetch these from the NNS here? They shouldn't
            // have changed, and it adds another async/await.
            let neuronIds = args.staking.ids();
            let before = TrieMap.TrieMap<Text, Nat64>(Text.equal, Text.hash);
            for ((k, v) in args.staking.balances().vals()) {
                before.put(Nat64.toText(k), v);
            };

            // Note: We compare before/after balances here because we are
            // forced to merge a "percentage", so the amount we merge might be
            // different than expected. However, this introduces a race
            // condition with 'FlushPendingDeposits', which transfers more ICP
            // into the neurons. So this must run before
            // 'FlushPendingDeposits'.
            var interest: Nat64 = 0;
            let merges = await args.neurons.mergeMaturities(neuronIds, 100);
            for (n in merges.vals()) {
                switch (n) {
                    case (#ok(neuron)) {
                        ignore args.staking.addOrRefresh(neuron);

                        // Add up the interest we successfully merged.
                        switch (before.get(Nat64.toText(neuron.id))) {
                            case (null) { P.unreachable() };
                            case (?beforeE8s) {
                                assert(neuron.cachedNeuronStakeE8s >= beforeE8s);
                                interest += neuron.cachedNeuronStakeE8s - beforeE8s
                            };
                        };
                    };
                    case (_) { };
                };
            };

            // See how much maturity we have pending
            if (interest <= 10_000) {
                return #err(#InsufficientMaturity);
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

        private func applyInterestToToken(now: Time.Time, interest: Nat, holders: [(Principal, Nat)], root: Principal, queueMint: QueueMintFn): ApplyInterestSummary {
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

        // ===== HELPER FUNCTIONS =====

        // helper to short ApplyInterestResults
        private func sortInterestByTime(a: ApplyInterestSummary, b: ApplyInterestSummary): Order.Order {
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

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade(): ?UpgradeData {
            return ?#v1({
                snapshot = snapshot;
                appliedInterest = appliedInterest.toArray();
                meanAprMicrobips = meanAprMicrobips;
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    snapshot := data.snapshot;
                    appliedInterest := Buffer.Buffer<ApplyInterestSummary>(data.appliedInterest.size());
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

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
import Ledger "../../nns-ledger";
import Token "../../DIP20/motoko/src/token";
import Account "../../DIP20/motoko/src/account";

module {
    public type UpgradeData = {
        #v1: {
            snapshot: ?[(Principal, Nat)];
            appliedInterest: [ApplyInterestSummary];
            meanAprMicrobips: Nat64;
            merges: [[(Nat64, Nat64, Neurons.NeuronResult)]];
        };
        #v2: {
            snapshot: ?[(Account.Account, Nat)];
            appliedInterest: [ApplyInterestSummary];
            meanAprMicrobips: Nat64;
            merges: [[(Nat64, Nat64, Neurons.NeuronResult)]];
        };
        #v3: {
            snapshot: ?[(Account.Account, Nat)];
            appliedInterest: [ApplyInterestSummary];
            meanAprMicrobips: Nat64;
            merges: [[(Nat64, Nat64, Neurons.NeuronResult)]];
            totalMaturity: Nat64;
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

    public type QueueMintFn = (to: Account.Account, amount: Nat64) -> Nat64;
    public type RefreshAvailableBalanceFn = () -> async Nat64;

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
        let microbips : Nat = 100_000_000;

        // State used across job runs
        private var snapshot : ?[(Account.Account, Nat)] = null;
        private var appliedInterest : Buffer.Buffer<ApplyInterestSummary> = Buffer.Buffer(0);
        private var meanAprMicrobips : Nat64 = 0;
        private var merges : Buffer.Buffer<[(Nat64, Nat64, Neurons.NeuronResult)]> = Buffer.Buffer(10);
        private var totalMaturity : Nat64 = 0;

        private func getAllHolders(): async [(Account.Account, Nat)] {
            return await args.token.getHolderAccounts(0, 0);
        };

        // ===== GETTER/SETTER FUNCTIONS =====

        public func setInitialSnapshot(): async (Text, [(Account.Account, Nat)]) {
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

        public func getMerges() : [[(Nat64, Nat64, Neurons.NeuronResult)]] {
            return merges.toArray();
        };

        public func getTotalMaturity() : Nat64 {
            return totalMaturity;
        };

        public func setTotalMaturity(v: Nat64) {
            totalMaturity := v;
        };

        // ===== JOB START FUNCTION =====

        // Distribute newly earned interest to token holders.
        public func run(now: Time.Time, root: Account.Account, queueMint: QueueMintFn, refreshAvailableBalance: RefreshAvailableBalanceFn): async ApplyInterestResult {
            // take a snapshot of the holders for tomorrow's interest.
            let nextHolders = await getAllHolders();
            let availableBalance = await refreshAvailableBalance();

            let neuronIds = args.staking.ids();

            let neuronsAfter = await args.neurons.list(?neuronIds);
            let sumAfter = sumMaturity(neuronsAfter);
            if (sumAfter < totalMaturity) {
                return #err(#InsufficientMaturity);
            };
            let interest: Nat64 = sumAfter - totalMaturity;

            // See how much maturity we have pending
            if (interest <= 10_000) {
                return #err(#InsufficientMaturity);
            };

            // Pay out the protocol cut and affiliate fees
            let apply = payProtocolAndAffiliates(
                now,
                Nat64.toNat(interest),
                Nat64.toNat(sumStake(neuronsAfter) + availableBalance),
                Option.get(snapshot, nextHolders),
                root,
                queueMint
            );

            // Update the snapshot for next time.
            snapshot := ?nextHolders;

            // Update the neuron cache for next time.
            ignore args.staking.addOrRefreshAll(neuronsAfter);
            totalMaturity := sumAfter;

            // Update the APY calculation
            appliedInterest.add(apply);
            appliedInterest := sortBuffer(appliedInterest, sortInterestByTime);
            updateMeanAprMicrobips();

            #ok(apply)
        };

        private func sumStake(neurons: [Neurons.Neuron]): Nat64 {
            var sum: Nat64 = 0;
            for (neuron in neurons.vals()) {
                sum += neuron.cachedNeuronStakeE8s;
            };
            sum
        };

        private func sumMaturity(neurons: [Neurons.Neuron]): Nat64 {
            var sum: Nat64 = 0;
            for (neuron in neurons.vals()) {
                sum += Option.get(neuron.stakedMaturityE8sEquivalent, 0: Nat64);
            };
            sum
        };

        // Preserve the last 10 merges to stop it growing forever
        private func logMerge(m: [(Nat64, Nat64, Neurons.NeuronResult)]) {
            let size = merges.size();
            if (size > 9) {
                let newMerges = Buffer.Buffer<[(Nat64, Nat64, Neurons.NeuronResult)]>(10);
                for (i in Iter.range(size-10, size-1)) {
                    newMerges.add(merges.get(i));
                };
                merges := newMerges;
            };
            merges.add(m);
        };

        private func payProtocolAndAffiliates(now: Time.Time, interest: Nat, totalIcp: Nat, holders: [(Account.Account, Nat)], root: Account.Account, queueMint: QueueMintFn): ApplyInterestSummary {
            assert(interest <= totalIcp);

            // Figure out the total amount owed the protocol (10% of the interest)
            let protocolInterest = interest / 10;
            assert(protocolInterest < totalIcp);

            var beforeStIcp : Nat = 0;
            for ((_, balance) in holders.vals()) {
                let (_, balance) = holders[i];
                beforeStIcp += balance;
            };

            if (interest == 0 or protocolInterest == 0 or beforeStIcp == 0) {
                return {
                    timestamp = now;
                    supply = {
                        before = { e8s = Nat64.fromNat(totalIcp - interest) };
                        after = { e8s = Nat64.fromNat(totalIcp) };
                    };
                    applied = { e8s = 0 : Nat64 };
                    remainder = { e8s = 0 : Nat64 };
                    totalHolders = holders.size();
                    affiliatePayouts = 0;
                };
            };

            // Convert the protocol portion to diluting stICP. Figure out how
            // much stICP to mint to the protocol + affiliates, so that the
            // minted amount represents a 10% share of the new interest.
            //
            //   protocolInterest / totalIcp = protocolStIcp / (beforeStIcp + protocolStIcp)
            //   protocolInterest = (totalIcp * protocolStIcp) / (beforeStIcp + protocolStIcp)
            //   protocolStIcp = (protocolInterest * beforeStIcp) / (totalIcp - protocolInterest)
            let protocolStIcp : Nat = (protocolInterest * beforeStIcp) / (totalIcp - protocolInterest);

            // For each affiliate, figure out how much they are owed.
            //
            // TODO: We could possibly make this more efficient by looping
            // through each affiliate, instead of each holder, since not all
            // holders will have an affiliate.
            var mints = Buffer.Buffer<(Account.Account, Nat)>(holders.size());
            var remainder = protocolStIcp;
            var affiliatePayouts : Nat = 0;
            for ((to, balance) in holders.vals()) {
                // Figure out the share of the protocolStIcp driven by this holder
                let share = (balance * protocolStIcp) / beforeStIcp;
                if (share > 0) {
                    // Check if there is an affiliate for this user
                    switch (args.referralTracker.payout(to.owner, share)) {
                        case (null) {};
                        case (?(affiliate, payout)) {
                            Debug.print("affiliate: " # debug_show(payout) # " to " # debug_show(affiliate));
                            mints.add(({owner=affiliate; subaccount=null}, payout));
                            affiliatePayouts += payout;
                            assert(payout <= remainder);
                            remainder -= payout;
                        };
                    }
                };
            };

            // Protocol takes the remainder. For now, just mint it to this
            // canister.
            if (remainder > 0) {
                mints.add((root, remainder));
                remainder := 0;
            };

            // Check everything matches up
            assert(affiliatePayouts+remainder == protocolStIcp);

            // Execute all mints
            for ((to, amount) in mints.vals()) {
                Debug.print("mint: " # debug_show(amount) # " to " # debug_show(to));
                ignore queueMint(to, Nat64.fromNat(amount));
            };


            return {
                timestamp = now;
                supply = {
                    before = { e8s = Nat64.fromNat(totalIcp - interest) };
                    after = { e8s = Nat64.fromNat(totalIcp) };
                };
                applied = { e8s = Nat64.fromNat(interest) };
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
            var sum : Nat = 0;
            var earliest : Time.Time  = last.timestamp;
            label range while (i > 0) {
                i := i - 1;
                let interest = appliedInterest.get(i);
                if (interest.timestamp < start) {
                    break range;
                };
                sum := sum + ((microbips * Nat64.toNat(interest.supply.after.e8s)) / Nat64.toNat(interest.supply.before.e8s)) - microbips;
                earliest := interest.timestamp;
            };
            // truncate to start of first day where we found an application.
            // (in case we didn't have 7 days of applications)
            earliest := (earliest / day) * day;
            // end of last day
            let latest = ((last.timestamp / day) * day) + day;
            assert(earliest < latest);
            // Find the number of days we've spanned
            let span = Int.abs((latest - earliest) / day);
            assert(span > 0);

            // Find the mean
            meanAprMicrobips := Nat64.fromNat(sum / span);

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


        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade(): ?UpgradeData {
            return ?#v3({
                snapshot = snapshot;
                appliedInterest = appliedInterest.toArray();
                meanAprMicrobips = meanAprMicrobips;
                merges = merges.toArray();
                totalMaturity = totalMaturity;
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    // Convert the old Principal snapshot to a new Account snapshot
                    let holders = switch (data.snapshot) {
                        case (null) { null };
                        case (?snapshot) {
                            let b = Buffer.Buffer<(Account.Account, Nat)>(snapshot.size());
                            for ((principal, balance) in snapshot.vals()) {
                                b.add(({owner=principal; subaccount=null}, balance));
                            };
                            ?b.toArray()
                        };
                    };
                    postupgrade(?#v2({
                        snapshot = holders;
                        appliedInterest = data.appliedInterest;
                        meanAprMicrobips = data.meanAprMicrobips;
                        merges = data.merges;
                    }));
                };
                case (?#v2(data)) {
                    postupgrade(?#v3({
                        snapshot = data.snapshot;
                        appliedInterest = data.appliedInterest;
                        meanAprMicrobips = data.meanAprMicrobips;
                        merges = data.merges;
                        totalMaturity = 0;
                    }));
                };
                case (?#v3(data)) {
                    snapshot := data.snapshot;
                    appliedInterest := Buffer.Buffer<ApplyInterestSummary>(data.appliedInterest.size());
                    for (x in data.appliedInterest.vals()) {
                        appliedInterest.add(x);
                    };
                    meanAprMicrobips := data.meanAprMicrobips;
                    merges := Buffer.Buffer<[(Nat64, Nat64, Neurons.NeuronResult)]>(data.merges.size());
                    for (x in data.merges.vals()) {
                        merges.add(x);
                    };
                    totalMaturity := data.totalMaturity;
                };
                case (_) { return; }
            };
        };
    };
};

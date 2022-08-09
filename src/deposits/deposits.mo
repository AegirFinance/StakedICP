import Array "mo:base/Array";
import AssocList "mo:base/AssocList";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Order "mo:base/Order";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";

import Account      "./Account";
import Hex          "./Hex";
import Neurons      "./Neurons";
import Owners       "./Owners";
import Referrals    "./Referrals";
import Staking      "./Staking";
import Util         "./Util";
import Withdrawals  "./Withdrawals";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
import Token "../DIP20/motoko/src/token";

// The deposits canister is the main backend canister for StakedICP. It
// forwards calls to several submodules, and manages daily recurring jobs via
// heartbeats.
shared(init_msg) actor class Deposits(args: {
    governance: Principal;
    ledger: Principal;
    ledgerCandid: Principal;
    token: Principal;
    owners: [Principal];
    stakingNeuron: ?{ id : { id : Nat64 }; accountId : Text };
}) = this {
    // Referrals subsystem
    private let referralTracker = Referrals.Tracker();
    private stable var stableReferralData : ?Referrals.UpgradeData = null;

    // Proposal-based neuron management subsystem
    private let neurons = Neurons.Manager({ governance = args.governance });
    private stable var stableNeuronsData : ?Neurons.UpgradeData = null;

    // Staking management subsystem
    private let staking = Staking.Manager({
        governance = args.governance;
        neurons = neurons;
    });
    private stable var stableStakingData : ?Staking.UpgradeData = null;

    // Withdrawals management subsystem
    private let withdrawals = Withdrawals.Manager({
        token = args.token;
        ledger = args.ledger;
        neurons = neurons;
    });
    private stable var stableWithdrawalsData : ?Withdrawals.UpgradeData = null;


    // Cost to transfer ICP on the ledger
    let icpFee: Nat = 10_000;
    let minimumDeposit: Nat = icpFee*10;

    // Makes date math simpler
    let second : Int = 1_000_000_000;
    let minute : Int = 60 * second;
    let hour : Int = 60 * minute;
    let day : Int = 24 * hour;

    // For apr calcs
    let microbips : Nat64 = 100_000_000;


    type NeuronId = { id : Nat64; };

    // Copied from Token due to compiler weirdness
    type TxReceipt = {
        #Ok: Nat;
        #Err: {
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
    };

    type DailyHeartbeatResponse = {
        #Ok : ({
            apply: Result.Result<ApplyInterestResult, Neurons.NeuronsError>;
            mergeStaked: ?[Neurons.Neuron];
            mergeDissolving: [Neurons.Neuron];
            flush: [Ledger.TransferResult];
            refresh: ?Neurons.NeuronsError;
            split: ?Neurons.NeuronsResult;
        });
        #Err: Neurons.NeuronsError;
    };

    type ApplyInterestResult = {
        timestamp : Time.Time;
        supply : {
            before : Ledger.Tokens;
            after : Ledger.Tokens;
        };
        applied : Ledger.Tokens;
        remainder : Ledger.Tokens;
        totalHolders: Nat;
        flush : ?TxReceipt;
        affiliatePayouts: Nat;
    };

    type WithdrawPendingDepositsResult = {
      args : Ledger.TransferArgs;
      result : Ledger.TransferResult;
    };

    public type Neuron = {
        id : NeuronId;
        accountId : Account.AccountIdentifier;
    };

    private stable var governance : Governance.Interface = actor(Principal.toText(args.governance));
    private stable var ledger : Ledger.Self = actor(Principal.toText(args.ledger));

    private stable var token : Token.Token = actor(Principal.toText(args.token));

    private stable var pendingMints : Trie.Trie<Principal, Nat64> = Trie.empty();
    private stable var snapshot : ?[(Principal, Nat)] = null;

    private stable var appliedInterestEntries : [ApplyInterestResult] = [];
    private var appliedInterest : Buffer.Buffer<ApplyInterestResult> = Buffer.Buffer(0);
    private stable var meanAprMicrobips : Nat64 = 0;

    // ===== OWNER FUNCTIONS =====

    private let owners = Owners.Owners(args.owners);
    private stable var stableOwners : ?Owners.UpgradeData = null;

    public shared(msg) func addOwner(candidate: Principal) {
        owners.add(msg.caller, candidate);
    };

    public shared(msg) func removeOwner(candidate: Principal) {
        owners.remove(msg.caller, candidate);
    };

    // ===== GETTER/SETTER FUNCTIONS =====

    public shared(msg) func setToken(_token: Principal) {
        owners.require(msg.caller);
        token := actor(Principal.toText(_token));
    };

    public shared(msg) func stakingNeurons(): async [{ id : NeuronId ; accountId : Text }] {
        staking.list()
    };

    public shared(msg) func stakingNeuronBalances(): async [(Nat64, Nat64)] {
        staking.balances()
    };

    private func stakingNeuronBalance(): Nat64 {
        var sum : Nat64 = 0;
        for ((id, balance) in staking.balances().vals()) {
            sum += balance;
        };
        sum
    };

    private func stakingNeuronMaturityE8s() : async Nat64 {
        let maturities = await neurons.maturities(staking.ids());
        var sum : Nat64 = 0;
        for ((id, maturities) in maturities.vals()) {
            sum += maturities;
        };
        sum
    };

    // Idempotently add a neuron to the tracked staking neurons. The neurons
    // added here must be manageable by the proposal neuron. The starting
    // balance will be minted as stICP to the canister's token account.
    public shared(msg) func addStakingNeuron(id: Nat64): async Neurons.NeuronResult {
        owners.require(msg.caller);
        switch (await neurons.refresh(id)) {
            case (#err(err)) { #err(err) };
            case (#ok(neuron)) {
                let isNew = staking.addOrRefresh(neuron);
                if isNew {
                    let canister = Principal.fromActor(this);
                    ignore queueMint(canister, neuron.cachedNeuronStakeE8s);
                    ignore await flushMint(canister);
                };
                #ok(neuron)
            };
        }
    };

    public shared(msg) func proposalNeuron(): async ?Neurons.Neuron {
        neurons.getProposalNeuron()
    };

    public shared(msg) func setProposalNeuron(id: Nat64): async Neurons.NeuronResult {
        owners.require(msg.caller);
        let neuron = await neurons.refresh(id);
        Result.iterate(neuron, neurons.setProposalNeuron);
        neuron
    };

    public shared(msg) func accountId() : async Text {
        return Account.toText(accountIdBlob());
    };

    private func accountIdBlob() : Account.AccountIdentifier {
        return Account.fromPrincipal(Principal.fromActor(this), Account.defaultSubaccount());
    };

    // ===== METRICS FUNCTIONS =====

    private stable var metricsCanister : ?Principal = null;
    public shared(msg) func setMetrics(m: ?Principal) {
        owners.require(msg.caller);
        metricsCanister := m;
    };

    public type Metrics = {
        aprMicrobips: Nat64;
        balances: [(Text, Nat64)];
        stakingNeuronBalance: ?Nat64;
        referralAffiliatesCount: Nat;
        referralLeads: [Referrals.LeadMetrics];
        referralPayoutsSum: Nat;
        lastHeartbeatAt: Time.Time;
        lastHeartbeatOk: Bool;
        lastHeartbeatInterestApplied: Nat64;
        // TODO: Add neurons metrics
    };

    // Expose metrics to track canister performance, and behaviour. These are
    // ingested and served by the "metrics" canister.
    public shared(msg) func metrics() : async Metrics {
        if (not owners.is(msg.caller)) {
            switch (metricsCanister) {
                case (null) {
                    throw Error.reject("metrics canister missing");
                };
                case (?expected) {
                    assert(msg.caller == expected);
                };
            };
        };

        var balance = (await ledger.account_balance({
            account = Blob.toArray(accountIdBlob());
        })).e8s;
        return {
            aprMicrobips = await aprMicrobips();
            balances = [
                ("ICP", balance),
                ("cycles", Nat64.fromNat(ExperimentalCycles.balance()))
            ];
            stakingNeuronBalance = ?stakingNeuronBalance();
            referralAffiliatesCount = referralTracker.affiliatesCount();
            referralLeads = referralTracker.leadMetrics();
            referralPayoutsSum = referralTracker.payoutsSum();
            lastHeartbeatAt = lastHeartbeatAt;
            lastHeartbeatOk = switch (lastHeartbeatResult) {
                case (?#Ok(_)) { true };
                case (_)       { false };
            };
            lastHeartbeatInterestApplied = switch (lastHeartbeatResult) {
                case (?#Ok({apply})) {
                    switch (apply) {
                        case (#ok({applied; remainder; affiliatePayouts})) {
                            applied.e8s + remainder.e8s + Nat64.fromNat(affiliatePayouts)
                        };
                        case (_) { 0 };
                    };
                };
                case (_)       { 0 };
            };
        };
    };

    // ===== INTEREST FUNCTIONS =====

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

    // List all neurons ready for disbursal. We will disburse them into the
    // deposit canister's default account, like it is a new deposit.
    // flushPendingDeposits will then route it to the right place.
    public shared(msg) func listNeuronsToDisburse(): async [Neurons.Neuron] {
        owners.require(msg.caller);
        withdrawals.listNeuronsToDisburse()
    };

    // Once we've disbursed them, remove them from the withdrawals neuron tracking
    public shared(msg) func removeDisbursedNeurons(ids: [Nat64]): async [Neurons.Neuron] {
        owners.require(msg.caller);
        withdrawals.removeDisbursedNeurons(ids)
    };

    // In case there was an issue with the automatic daily heartbeat, the
    // canister owner can call it manually. Repeated calling should be
    // effectively idempotent.
    public shared(msg) func manualHeartbeat(when: ?Time.Time): async DailyHeartbeatResponse {
        owners.require(msg.caller);
        await dailyHeartbeat(when)
    };

    // called every day by the heartbeat function.
    private func dailyHeartbeat(when: ?Time.Time) : async DailyHeartbeatResponse {
        // Merge the interest
        let interest = await stakingNeuronMaturityE8s();
        let (applyInterestResult, mergeStakedResult): (Result.Result<ApplyInterestResult, Neurons.NeuronsError>, ?[Neurons.Neuron]) = if (interest <= 10_000) {
            (#err(#InsufficientMaturity), null)
        } else {
            let (percentage, applyResult) = await applyInterest(interest, when);
            // TODO: Error handling here. Do this first to confirm it worked? After
            // is nice as we can the merge "manually" to ensure it merges.
            let merges = await mergeMaturities(staking.ids(), Nat32.fromNat(Nat64.toNat(percentage)));
            for (n in merges.vals()) {
                ignore staking.addOrRefresh(n);
            };
            (#ok(applyResult), ?merges)
        };

        // Flush pending deposits
        let tokenE8s = Nat64.fromNat((await token.getMetadata()).totalSupply);
        let flushResult = await flushPendingDeposits(tokenE8s);
        let refreshResult = await refreshAllStakingNeurons();

        // Merge maturity on dissolving neurons. Merged maturity here will be
        // disbursed when the neuron is dissolved, and will be a "bonus" put
        // towards filling pending withdrawals early.
        let mergeDissolvingResult = await mergeMaturities(withdrawals.ids(), 100);
        ignore withdrawals.addNeurons(mergeDissolvingResult);
        // figure out how much we have dissolving for withdrawals
        let dissolving = withdrawals.totalDissolving();
        let pending = withdrawals.totalPending();
        let splitResult: ?Neurons.NeuronsResult = if (pending > dissolving) {
            // figure out how much we need dissolving for withdrawals
            let needed = pending - dissolving;
            // Split the difference off from staking neurons
            switch (staking.splitNeurons(needed)) {
                case (#err(err)) {
                    ?#err(err)
                };
                case (#ok(toSplit)) {
                    // Do the splits on the nns and find the new neurons.
                    let newNeurons = Buffer.Buffer<Neurons.Neuron>(toSplit.size());
                    for ((id, amount) in toSplit.vals()) {
                        switch (await neurons.split(id, amount)) {
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
                        case (#err(err)) { ?#err(err) };
                        case (#ok(newNeurons)) { ?#ok(withdrawals.addNeurons(newNeurons)) };
                    }
                };
            }
        } else {
            null
        };

        #Ok({
            apply = applyInterestResult;
            mergeStaked = mergeStakedResult;
            mergeDissolving = mergeDissolvingResult;
            flush = flushResult;
            refresh = refreshResult;
            split = splitResult;
        })
    };

    private func dissolveNeurons(ns: [Neurons.Neuron]): async Neurons.NeuronsResult {
        let newNeurons = Buffer.Buffer<Neurons.Neuron>(ns.size());
        for (n in ns.vals()) {
            let neuron = switch (n.dissolveState) {
                case (?#DissolveDelaySeconds(delay)) {
                    // Make sure the neuron is dissolving
                    switch (await neurons.dissolve(n.id)) {
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

    private func mergeMaturities(ids: [Nat64], percentage: Nat32): async [Neurons.Neuron] {
        Array.mapFilter<Result.Result<Neurons.Neuron, Neurons.NeuronsError>, Neurons.Neuron>(
            await neurons.mergeMaturities(withdrawals.ids(), percentage),
            func(r) { Result.toOption(r) },
        )
    };

    // Distribute newly earned interest to token holders.
    private func applyInterest(interest: Nat64, when: ?Time.Time) : async (Nat64, ApplyInterestResult) {
        let now = Option.get(when, Time.now());

        let result = await applyInterestToToken(now, Nat64.toNat(interest));

        appliedInterest.add(result);
        appliedInterest := sortBuffer(appliedInterest, sortInterestByTime);

        updateMeanAprMicrobips();

        // Figure out the percentage to merge
        let percentage = ((interest - result.remainder.e8s) * 100) / interest;
        return (percentage, result);
    };

    // Use new incoming deposits to attempt to rebalance the buckets, where
    // "the buckets" are:
    // - pending withdrawals
    // - ICP in the canister
    // - staking neurons
    private func flushPendingDeposits(tokenE8s: Nat64): async [Ledger.TransferResult] {
        var balance = await availableBalance();
        if (balance == 0) {
            return [];
        };


        let applied = withdrawals.applyIcp(balance);
        balance -= Nat64.min(balance, applied);
        if (balance == 0) {
            return [];
        };

        let transfers = staking.depositIcp(tokenE8s, balance, null);


        let b = Buffer.Buffer<Ledger.TransferResult>(transfers.size());
        for (transfer in transfers.vals()) {
            b.add(await ledger.transfer(transfer));
        };
        return b.toArray();
    };

    private func getAllHolders(): async [(Principal, Nat)] {
        let info = await token.getTokenInfo();
        // *2 here is because this is not atomic, so if anyone joins in the
        // meantime.
        return await token.getHolders(0, info.holderNumber*2);
    };

    // Calculate shares owed and distribute interest to token holders.
    private func applyInterestToToken(now: Time.Time, interest: Nat): async ApplyInterestResult {
        let nextHolders = await getAllHolders();
        let holders = Option.get(snapshot, nextHolders);

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
                flush = null;
                affiliatePayouts = 0;
            };
        };
        assert(interest > 0);

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
            switch (referralTracker.payout(to, share)) {
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

        // Deal with our share
        //
        // If there is 1+ icp left, we'll spawn, so return it as a remainder,
        // otherwise mint it to the root so the neuron matches up.
        if (remainder > 0) {
            // The gotcha here is that we can only merge maturity in whole
            // percentages, so round down to the nearest whole percentage.
            let spawnablePercentage = (remainder * 100) / interest;
            let spawnableE8s = (interest * spawnablePercentage) / 100;
            assert(spawnableE8s <= remainder);

            let root = Principal.fromActor(this);
            if (spawnableE8s < 100_000_000) {
                // Less than than 1 icp left, but there is some remainder, so
                // just mint all the remainder to root. This keeps the neuron
                // and token matching, and tidy.
                Debug.print("remainder: " # debug_show(remainder) # " to " # debug_show(root));
                ignore queueMint(root, Nat64.fromNat(remainder));
                applied += remainder;
                remainder := 0;
            } else {
                // More than 1 icp left, so we can spawn!

                // Gap is the fractional percentage we can't spawn, so we'll merge
                // it, and mint to root
                //
                // e.g. if the remainder is 7.5% of total, we can't merge
                // 92.5%, so merge 93%, and mint the gap 0.5%, to root.
                let gap = remainder - spawnableE8s;

                // Mint the gap to root
                Debug.print("remainder: " # debug_show(gap) # " to " # debug_show(root));
                ignore queueMint(root, Nat64.fromNat(gap));
                applied += gap;

                // Return the spawnable amount as remainder. This is what we'll
                // get when we spawn our cut from the neuron.
                remainder := spawnableE8s;
            };
        };

        // Check everything matches up
        assert(applied+affiliatePayouts+remainder == interest);

        // Execute the mints.
        let flush = await flushAllMints();

        // Update the snapshot for next time.
        snapshot := ?nextHolders;

        return {
            timestamp = now;
            supply = {
                before = { e8s = Nat64.fromNat(beforeSupply) };
                after = { e8s = Nat64.fromNat(beforeSupply+applied+affiliatePayouts) };
            };
            applied = { e8s = Nat64.fromNat(applied) };
            remainder = { e8s = Nat64.fromNat(remainder) };
            totalHolders = holders.size();
            flush = ?flush;
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

    // Refresh all neurons, fetching current data from the NNS. This is
    // needed e.g. if we have transferred more ICP into a staking neuron,
    // to update the cached balances.
    public func refreshAllStakingNeurons(): async ?Neurons.NeuronsError {
        for (id in staking.ids().vals()) {
            switch (await neurons.refresh(id)) {
                case (#err(err)) { return ?err };
                case (#ok(neuron)) {
                    ignore staking.addOrRefresh(neuron);
                };
            };
        };
        return null;
    };

    // Getter for the current APR in microbips
    public query func aprMicrobips() : async Nat64 {
        return meanAprMicrobips;
    };

    // ===== REFERRAL FUNCTIONS =====

    public type ReferralStats = {
        code: Text;
        count: Nat;
        earned: Nat;
    };

    // Get a user's current referral stats. Used for the "Rewards" page.
    public shared(msg) func getReferralStats(): async ReferralStats {
        let stats = referralTracker.getStats(msg.caller);
        return {
            code = await referralTracker.getCode(msg.caller);
            count = stats.count;
            earned = stats.earned;
        };
    };

    // ===== DEPOSIT FUNCTIONS =====

    // Return the account ID specific to this user's subaccount. This is the
    // address where the user should transfer their deposit ICP.
    public shared(msg) func getDepositAddress(code: ?Text): async Text {
        Debug.print("[Referrals.touch] user: " # debug_show(msg.caller) # ", code: " # debug_show(code));
        referralTracker.touch(msg.caller, code);
        Account.toText(Account.fromPrincipal(Principal.fromActor(this), Account.principalToSubaccount(msg.caller)));
    };

    // Same as getDepositAddress, but allows the canister owner to find it for
    // a specific user.
    public shared(msg) func getDepositAddressFor(user: Principal): async Text {
        owners.require(msg.caller);
        Account.toText(Account.fromPrincipal(Principal.fromActor(this), Account.principalToSubaccount(user)));
    };

    public type DepositErr = {
        #BalanceLow;
        #TransferFailure;
    };

    public type DepositReceipt = {
        #Ok: Nat;
        #Err: DepositErr;
    };

    private func principalKey(p: Principal) : Trie.Key<Principal> {
        return {
            key = p;
            hash = Principal.hash(p);
        };
    };

    // After the user transfers their ICP to their depositAddress, process the
    // deposit, be minting the tokens.
    public shared(msg) func depositIcp(): async DepositReceipt {
        await doDepositIcpFor(msg.caller);
    };

    // After the user transfers their ICP to their depositAddress, process the
    // deposit, be minting the tokens.
    public shared(msg) func depositIcpFor(user: Principal): async DepositReceipt {
        owners.require(msg.caller);
        await doDepositIcpFor(user)
    };

    private func doDepositIcpFor(user: Principal): async DepositReceipt {
        // Calculate target subaccount
        let subaccount = Account.principalToSubaccount(user);
        let source_account = Account.fromPrincipal(Principal.fromActor(this), subaccount);

        // Check ledger for value
        let balance = await ledger.account_balance({ account = Blob.toArray(source_account) });

        // Transfer to staking neuron
        if (Nat64.toNat(balance.e8s) <= minimumDeposit) {
            return #Err(#BalanceLow);
        };
        let fee = { e8s = Nat64.fromNat(icpFee) };
        let amount = { e8s = balance.e8s - fee.e8s };
        let icp_receipt = await ledger.transfer({
            memo : Nat64    = 0;
            from_subaccount = ?Blob.toArray(subaccount);
            to              = Blob.toArray(accountIdBlob());
            amount          = amount;
            fee             = fee;
            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
        });

        switch icp_receipt {
            case ( #Err _) {
                return #Err(#TransferFailure);
            };
            case _ {};
        };

        // Mint the new tokens
        Debug.print("[Referrals.convert] user: " # debug_show(user));
        referralTracker.convert(user);
        ignore queueMint(user, amount.e8s);
        ignore await flushMint(user);

        return #Ok(Nat64.toNat(amount.e8s));
    };

    // For safety, minting tokens is a two-step process. First we queue them
    // locally, in case the async mint call fails.
    private func queueMint(to : Principal, amount : Nat64) : Nat64 {
        let key = principalKey(to);
        let existing = Option.get(Trie.find(pendingMints, key, Principal.equal), 0 : Nat64);
        let total = existing + amount;
        pendingMints := Trie.replace(pendingMints, key, Principal.equal, ?total).0;
        return total;
    };

    // Execute the pending mints for a specific user on the token canister.
    private func flushMint(to : Principal) : async TxReceipt {
        let key = principalKey(to);
        let total = Option.get(Trie.find(pendingMints, key, Principal.equal), 0 : Nat64);
        if (total == 0) {
            return #Err(#AmountTooSmall);
        };
        Debug.print("minting: " # debug_show(total) # " to " # debug_show(to));
        let result = await token.mint(to, Nat64.toNat(total));
        pendingMints := Trie.remove(pendingMints, key, Principal.equal).0;
        return result;
    };

    // Execute all the pending mints on the token canister.
    private func flushAllMints() : async TxReceipt {
        let mints = Trie.toArray<Principal, Nat64, (Principal, Nat)>(pendingMints, func(k, v) {
            (k, Nat64.toNat(v))
        });
        for ((to, total) in mints.vals()) {
            Debug.print("minting: " # debug_show(total) # " to " # debug_show(to));
        };
        switch (await token.mintAll(mints)) {
            case (#Err(err)) {
                return #Err(err);
            };
            case (#Ok(count)) {
                pendingMints := Trie.empty();
                return #Ok(count);
            };
        };
    };

    // ===== WITHDRAWAL FUNCTIONS =====

    // Show currently available ICP in this canister. This ICP retained for
    // withdrawals.
    public shared(msg) func availableBalance() : async Nat64 {
        let balance = (await ledger.account_balance({
            account = Blob.toArray(accountIdBlob());
        })).e8s;
        let reserved = withdrawals.reservedIcp();
        if (reserved >= balance) {
            0
        } else {
            balance - reserved
        }
    };

    // Datapoints representing available liquidity at a point in time.
    // `[(delay, amount)]`
    public type AvailableLiquidityGraph = [(Int, Nat64)];

    // Generate datapoints for a graph representing how much total liquidity is
    // available over time.
    // TODO: Cache this or memoize it or something to make it cheaper.
    public func availableLiquidityGraph(): async AvailableLiquidityGraph {
        let neurons = staking.availableLiquidityGraph();
        let b = Buffer.Buffer<(Int, Nat64)>(neurons.size()+1);
        b.add((0, await availableBalance()));
        for ((delay, balance) in neurons.vals()) {
            b.add((delay, balance));
        };
        b.toArray();
    };

    private func availableLiquidity(amount: Nat64): (Int, Nat64) {
        var maxDelay: Int = 0;
        var sum: Nat64 = 0;
        // Is there enough available liquidity in the neurons?
        // Figure out the unstaking schedule
        for ((delay, liquidity) in staking.availableLiquidityGraph().vals()) {
            if (sum >= amount) {
                return (maxDelay, sum);
            };
            sum += Nat64.min(liquidity, amount-sum);
            maxDelay := Int.max(maxDelay, delay);
        };
        return (maxDelay, sum);
    };


    // Create a new withdrawal for a user. This will burn the corresponding
    // amount of tokens, locking them while the withdrawal is pending.
    public shared(msg) func createWithdrawal(user: Principal, total: Nat64) : async Result.Result<Withdrawals.Withdrawal, Withdrawals.WithdrawalsError> {
        if (msg.caller != user) {
            owners.require(msg.caller);
        };
        let availableCash = await availableBalance();
        var delay: Int = 0;
        var availableNeurons: Nat64 = 0;
        if (total > availableCash) {
            let (d, a) = availableLiquidity(total - availableCash);
            delay := d;
            availableNeurons := a;
        };
        if (availableCash+availableNeurons < total) {
            return #err(#InsufficientLiquidity);
        };

        // Burn the tokens from the user. This makes sure there is enough
        // balance for the user, avoiding re-entrancy.
        let burn = await token.burnFor(user, Nat64.toNat(total));
        switch (burn) {
            case (#Err(err)) {
                return #err(#TokenError(err));
            };
            case (#Ok(_)) { };
        };

        // TODO: Re-check we have enough cash+neurons, to avoid re-entrancy or timing attacks

        return #ok(withdrawals.createWithdrawal(user, total, availableCash, delay));
    };

    // Complete withdrawal(s), transferring the ready amount to the
    // address/principal of a user's choosing.
    public shared(msg) func completeWithdrawal(user: Principal, amount: Nat64, to: Text): async Withdrawals.PayoutResult {
        if (msg.caller != user) {
            owners.require(msg.caller);
        };

        // See if we got a valid address to send to.
        //
        // Try to parse text as an address or a principal. If a principal, return
        // the default subaccount address for that principal.
        let toAddress = switch (Account.fromText(to)) {
            case (#err(_)) {
                // Try to parse as a principal
                try {
                    Account.fromPrincipal(Principal.fromText(to), Account.defaultSubaccount())
                } catch (error) {
                    return #err(#InvalidAddress);
                };
            };
            case (#ok(toAddress)) {
                if (Account.validateAccountIdentifier(toAddress)) {
                    toAddress
                } else {
                    return #err(#InvalidAddress);
                }
            };
        };

        let (transferArgs, revert) = switch (withdrawals.completeWithdrawal(user, amount, toAddress)) {
            case (#err(err)) { return #err(err); };
            case (#ok(a)) { a };
        };
        try {
            let transfer = await ledger.transfer(transferArgs);
            switch (transfer) {
                case (#Ok(block)) {
                    #ok(block)
                };
                case (#Err(#InsufficientFunds{})) {
                    // Not enough ICP in the contract
                    revert();
                    #err(#InsufficientLiquidity)
                };
                case (#Err(err)) {
                    revert();
                    #err(#TransferError(err))
                };
            }
        } catch (error) {
            revert();
            #err(#Other(Error.message(error)))
        }
    };

    // List all withdrawals for a user.
    public shared(msg) func listWithdrawals(user: Principal) : async [Withdrawals.Withdrawal] {
        if (msg.caller != user) {
            owners.require(msg.caller);
        };
        return withdrawals.withdrawalsFor(user);
    };

    // ===== HELPER FUNCTIONS =====

    public shared(msg) func setInitialSnapshot(): async (Text, [(Principal, Nat)]) {
        owners.require(msg.caller);
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

    public shared(msg) func getAppliedInterestResults(): async [ApplyInterestResult] {
        owners.require(msg.caller);
        return Iter.toArray(appliedInterestEntries.vals());
    };

    public shared(msg) func neuronAccountId(controller: Principal, nonce: Nat64): async Text {
        owners.require(msg.caller);
        return Account.toText(Util.neuronAccountId(args.governance, controller, nonce));
    };

    public shared(msg) func neuronAccountIdSub(controller: Principal, subaccount: Blob.Blob): async Text {
        owners.require(msg.caller);
        return Account.toText(Account.fromPrincipal(args.governance, subaccount));
    };

    // ===== HEARTBEAT FUNCTIONS =====

    private stable var lastHeartbeatAt : Time.Time = if (appliedInterest.size() > 0) {
        appliedInterest.get(appliedInterest.size()-1).timestamp
    } else {
        Time.now()
    };
    private stable var lastHeartbeatResult : ?DailyHeartbeatResponse = null;

    system func heartbeat() : async () {
        let next = lastHeartbeatAt + day;
        let now = Time.now();
        if (now < next) {
            return;
        };
        lastHeartbeatAt := now;
        try {
            lastHeartbeatResult := ?(await dailyHeartbeat(?now));
        } catch (error) {
            lastHeartbeatResult := ?#Err(#Other(Error.message(error)));
        };
    };

    public shared(msg) func getLastHeartbeatResult(): async ?DailyHeartbeatResponse {
        owners.require(msg.caller);
        lastHeartbeatResult
    };

    // For manual recovery, in case of an issue with the most recent heartbeat.
    public shared(msg) func setLastHeartbeatAt(when: Time.Time): async () {
        owners.require(msg.caller);
        lastHeartbeatAt := when;
    };

    // ===== UPGRADE FUNCTIONS =====

    system func preupgrade() {
        // convert the buffer to a stable array
        appliedInterestEntries := appliedInterest.toArray();

        stableReferralData := referralTracker.preupgrade();

        stableNeuronsData := neurons.preupgrade();

        stableStakingData := staking.preupgrade();

        stableWithdrawalsData := withdrawals.preupgrade();

        stableOwners := owners.preupgrade();
    };

    system func postupgrade() {
        // convert the stable array back to a buffer.
        appliedInterest := Buffer.Buffer(appliedInterestEntries.size());
        for (x in appliedInterestEntries.vals()) {
            appliedInterest.add(x);
        };

        referralTracker.postupgrade(stableReferralData);
        stableReferralData := null;

        neurons.postupgrade(stableNeuronsData);
        stableNeuronsData := null;

        staking.postupgrade(stableStakingData);
        stableStakingData := null;

        withdrawals.postupgrade(stableWithdrawalsData);
        stableWithdrawalsData := null;

        owners.postupgrade(stableOwners);
        stableOwners := null;
    };

};

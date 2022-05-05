import Array "mo:base/Array";
import AssocList "mo:base/AssocList";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
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
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";

import Account      "./Account";
import Hex          "./Hex";
import Owners       "./Owners";
import Referrals    "./Referrals";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
import Token "../DIP20/motoko/src/token";

shared(init_msg) actor class Deposits(args: {
    governance: Principal;
    ledger: Principal;
    ledgerCandid: Principal;
    token: Principal;
    owners: [Principal];
    stakingNeuron: ?{ id : { id : Nat64 }; accountId : Text };
}) = this {
    private let referralTracker = Referrals.Tracker();
    private stable var stableReferralData : ?Referrals.UpgradeData = null;

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

    public type StakingNeuron = {
        id : NeuronId;
        accountId : Account.AccountIdentifier;
    };

    private stable var governance : Governance.Interface = actor(Principal.toText(args.governance));
    private stable var ledger : Ledger.Self = actor(Principal.toText(args.ledger));

    private stable var token : Token.Token = actor(Principal.toText(args.token));
    private stable var stakingNeuron_ : ?StakingNeuron = switch (args.stakingNeuron) {
        case (null) { null };
        case (?n) {
            ?{
                id = n.id;
                accountId = switch (Account.fromText(n.accountId)) {
                    case (#err(_)) { P.unreachable() };
                    case (#ok(x)) { x };
                };
            };
        };
    };

    private stable var balances : Trie.Trie<Principal, Nat64> = Trie.empty();
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

    public shared(msg) func stakingNeuron(): async ?{ id : NeuronId ; accountId : Text } {
        return switch (stakingNeuron_) {
            case (null) { null };
            case (?n) {
                ?{
                    id = n.id;
                    accountId = Account.toText(n.accountId);
                }
            };
        };
    };

    private func stakingNeuronBalance(): async ?Nat64 {
        return switch (stakingNeuron_) {
            case (null) { null };
            case (?n) {
                ?(await ledger.account_balance({
                    account = Blob.toArray(n.accountId);
                })).e8s;
            };
        };
    };

    private func stakingNeuronMaturityE8s() : async ?Nat64 {
        switch (stakingNeuron_) {
            case (null) { null };
            case (?neuron) {
                let id = neuron.id.id;
                let response = await governance.list_neurons({
                    neuron_ids = [id];
                    include_neurons_readable_by_caller = true;
                });
                let found = Option.map(
                    Array.find(
                        response.full_neurons,
                        func(n: Governance.Neuron): Bool {
                            return Option.get(n.id, {id=0:Nat64}).id == id;
                        }
                    ),
                    func(n: Governance.Neuron): Nat64 {
                       n.maturity_e8s_equivalent
                    }
                );
            };
        }
    };

    public shared(msg) func setStakingNeuron(n: { id : NeuronId ; accountId : Text }) {
        owners.require(msg.caller);
        stakingNeuron_ := ?{
            id = n.id;
            accountId = switch (Account.fromText(n.accountId)) {
                case (#err(_)) {
                    assert(false);
                    loop {};
                };
                case (#ok(x)) { x };
            };
        };
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
    };

    public shared(msg) func metrics() : async Metrics {
        if (not owners.is(msg.caller)) {
            switch (metricsCanister) {
                case (null) {
                    assert(false);
                    loop {};
                };
                case (?expected) {
                    assert(msg.caller == expected);
                };
            };
        };

        var balance = (await ledger.account_balance({
            account = Blob.toArray(accountIdBlob());
        })).e8s;
        for ((_, amount) in Trie.iter(balances)) {
            balance := balance + amount;
        };
        return {
            aprMicrobips = await aprMicrobips();
            balances = [
                ("ICP", balance),
                ("cycles", Nat64.fromNat(ExperimentalCycles.balance()))
            ];
            stakingNeuronBalance = await stakingNeuronBalance();
            referralAffiliatesCount = referralTracker.affiliatesCount();
            referralLeads = referralTracker.leadMetrics();
            referralPayoutsSum = referralTracker.payoutsSum();
        };
    };

    // ===== INTEREST FUNCTIONS =====

    private func sortInterestByTime(a: ApplyInterestResult, b: ApplyInterestResult): Order.Order {
      Int.compare(a.timestamp, b.timestamp)
    };

    // Buffers have not sort, implement it ourselves.
    private func sortBuffer<A>(buf: Buffer.Buffer<A>, cmp: (A, A) -> Order.Order): Buffer.Buffer<A> {
        let result = Buffer.Buffer<A>(buf.size());
        for (x in Array.sort(buf.toArray(), cmp).vals()) {
            result.add(x);
        };
        result
    };

    public shared(msg) func applyInterestFromNeuron(when: ?Time.Time) : async ?(ApplyInterestResult, [(Nat, Governance.ManageNeuron)]) {
        owners.require(msg.caller);
        switch (stakingNeuron_, await stakingNeuronMaturityE8s()) {
            case (null, _)      { null };
            case (_, null)      { null };
            case (_, ?0)        { null };
            case (?neuron, ?interest) {
                switch (await doApplyInterest(interest, when)) {
                    case (null)      { null };
                    case (?(percentage, result)) {
                        ?(result, [
                            // TODO: store the rpc id somewhere, and handle results
                            (0, {
                                id = null;
                                command = ?#MergeMaturity({
                                    percentage_to_merge = Nat32.fromNat(Nat64.toNat(percentage))
                                });
                                neuron_id_or_subaccount = ?#NeuronId(neuron.id);
                            })
                        ]);
                    };
                }
            };
        }
    };

    public shared(msg) func applyInterest(interest: Nat64, when: ?Time.Time) : async ?(Nat64, ApplyInterestResult) {
        owners.require(msg.caller);
        await doApplyInterest(interest, when);
    };

    private func doApplyInterest(interest: Nat64, when: ?Time.Time) : async ?(Nat64, ApplyInterestResult) {
        let now = Option.get(when, Time.now());

        let result = await applyInterestToToken(now, Nat64.toNat(interest));

        appliedInterest.add(result);
        appliedInterest := sortBuffer(appliedInterest, sortInterestByTime);

        updateMeanAprMicrobips();

        // Figure out the percentage to merge
        let percentage = ((interest - result.remainder.e8s) * 100) / interest;
        return ?(percentage, result);
    };

    private func getAllHolders(): async [(Principal, Nat)] {
        let info = await token.getTokenInfo();
        // *2 here is because this is not atomic, so if anyone joins in the
        // meantime.
        return await token.getHolders(0, info.holderNumber*2);
    };

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

        // 7 days from the last time we applied interest, truncated to the utc day start.
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

    public query func aprMicrobips() : async Nat64 {
        return meanAprMicrobips;
    };

    // ===== REFERRAL FUNCTIONS =====

    public type ReferralStats = {
        code: Text;
        count: Nat;
        earned: Nat;
    };

    public shared(msg) func getReferralStats(): async ReferralStats {
        let stats = referralTracker.getStats(msg.caller);
        return {
            code = await referralTracker.getCode(msg.caller);
            count = stats.count;
            earned = stats.earned;
        };
    };

    // ===== DEPOSIT FUNCTIONS =====

    // Return the account ID specific to this user's subaccount
    public shared(msg) func getDepositAddress(code: ?Text): async Text {
        Debug.print("[Referrals.touch] user: " # debug_show(msg.caller) # ", code: " # debug_show(code));
        referralTracker.touch(msg.caller, code);
        Account.toText(Account.fromPrincipal(Principal.fromActor(this), Account.principalToSubaccount(msg.caller)));
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

    // After user transfers ICP to the target subaccount
    public shared(msg) func depositIcp(): async DepositReceipt {
        let neuron = stakingNeuron_;
        let to = switch (neuron) {
            case (null) {
                // contract not configured.
                assert(false);
                loop {};
            };
            case (?neuron) {
                Blob.toArray(neuron.accountId)
            };
        };

        // Calculate target subaccount
        let subaccount = Account.principalToSubaccount(msg.caller);
        let source_account = Account.fromPrincipal(Principal.fromActor(this), subaccount);

        // Check ledger for value
        let balance = await ledger.account_balance({ account = Blob.toArray(source_account) });

        // TODO: Refactor this to a Triemap
        let key = principalKey(msg.caller);
        balances := Trie.put(balances, key, Principal.equal, balance.e8s).0;

        // Transfer to staking neuron
        if (Nat64.toNat(balance.e8s) <= minimumDeposit) {
            return #Err(#BalanceLow);
        };
        let fee = { e8s = Nat64.fromNat(icpFee) };
        let amount = { e8s = balance.e8s - fee.e8s };
        let icp_receipt = await ledger.transfer({
            memo : Nat64    = 0;
            from_subaccount = ?Blob.toArray(subaccount);
            to              = to;
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

        balances := Trie.put(balances, key, Principal.equal, 0 : Nat64).0;

        // Mint the new tokens
        Debug.print("[Referrals.convert] user: " # debug_show(msg.caller));
        referralTracker.convert(msg.caller);
        ignore queueMint(msg.caller, amount.e8s);
        ignore await flushMint(msg.caller);

        // Refresh the neuron balance, if we deposited directly
        switch (neuron) {
            case (null) {
                Debug.print("Staking neuron not configured for deposit");
            };
            case (?neuron) {
                Debug.print("Staking neuron refreshing: " # debug_show(neuron.id));
                let refresh = await governance.manage_neuron({
                    id = null;
                    command = ?#ClaimOrRefresh({ by = ?#NeuronIdOrSubaccount({}) });
                    neuron_id_or_subaccount = ?#NeuronId(neuron.id);
                });
            };
        };

        return #Ok(Nat64.toNat(amount.e8s));
    };

    // First we queue them locally, in case the async mint call fails.
    private func queueMint(to : Principal, amount : Nat64) : Nat64 {
        let key = principalKey(to);
        let existing = Option.get(Trie.find(pendingMints, key, Principal.equal), 0 : Nat64);
        let total = existing + amount;
        pendingMints := Trie.replace(pendingMints, key, Principal.equal, ?total).0;
        return total;
    };

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

    // ===== UPGRADE FUNCTIONS =====

    system func preupgrade() {
        // convert the buffer to a stable array
        appliedInterestEntries := appliedInterest.toArray();

        stableReferralData := referralTracker.preupgrade();

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

        owners.postupgrade(stableOwners);
        stableOwners := null;
    };

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
};

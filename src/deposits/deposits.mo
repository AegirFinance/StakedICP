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
import TrieMap "mo:base/TrieMap";

import Account      "./Account";
import Daily        "./Daily";
import Scheduler    "./Scheduler";
import Hex          "./Hex";
import Neurons      "./Neurons";
import Owners       "./Owners";
import Referrals    "./Referrals";
import Staking      "./Staking";
import Util         "./Util";
import Withdrawals  "./Withdrawals";
import Governance "../governance/Governance";
import Ledger "../ledger/Ledger";
import Metrics      "../metrics/types";
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

    // Background job processing subsystem
    private let scheduler = Scheduler.Scheduler();
    private stable var stableSchedulerData : ?Scheduler.UpgradeData = null;

    // State machine to track interest/maturity/neurons etc
    private let daily = Daily.Job({
        ledger = actor(Principal.toText(args.ledger));
        neurons = neurons;
        referralTracker = referralTracker;
        staking = staking;
        token = actor(Principal.toText(args.token));
        withdrawals = withdrawals;
    });
    private stable var stableDailyData : ?Daily.UpgradeData = null;

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
    type TxReceiptError = {
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
    type TxReceipt = {
        #Ok: Nat;
        #Err: TxReceiptError;
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

    private var pendingMints = TrieMap.TrieMap<Principal, Nat64>(Principal.equal, Principal.hash);
    private stable var stablePendingMints : ?[(Principal, Nat64)] = null;

    private stable var snapshot : ?[(Principal, Nat)] = null;

    private stable var appliedInterestEntries : [ApplyInterestResult] = [];
    private var appliedInterest : Buffer.Buffer<ApplyInterestResult> = Buffer.Buffer(0);
    private stable var meanAprMicrobips : Nat64 = 0;

    private stable var cachedLedgerBalanceE8s : Nat64 = 0;

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
                    ignore flushMint(canister);
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

    // Getter for the current APR in microbips
    public query func aprMicrobips() : async Nat64 {
        return meanAprMicrobips;
    };

    // ===== METRICS FUNCTIONS =====

    private stable var metricsCanister : ?Principal = null;
    public shared(msg) func setMetrics(m: ?Principal) {
        owners.require(msg.caller);
        metricsCanister := m;
    };

    // Expose metrics to track canister performance, and behaviour. These are
    // ingested and served by the "metrics" canister.
    public shared(msg) func metrics() : async [Metrics.Metric] {
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

        let neuronsMetrics = await neurons.metrics();

        let ms = Buffer.Buffer<Metrics.Metric>(0);
        ms.add({
            name = "apr_microbips";
            t = "gauge";
            help = ?"latest apr in microbips";
            labels = [];
            value = Nat64.toText(meanAprMicrobips);
        });
        ms.add({
            name = "canister_balance_e8s";
            t = "gauge";
            help = ?"canister balance for a token in e8s";
            labels = [("token", "ICP"), ("canister", "deposits")];
            value = Nat64.toText(cachedLedgerBalanceE8s);
        });
        ms.add({
            name = "canister_balance_e8s";
            t = "gauge";
            help = ?"canister balance for a token in e8s";
            labels = [("token", "cycles"), ("canister", "deposits")];
            value = Nat.toText(ExperimentalCycles.balance());
        });
        ms.add({
            name = "pending_mint_count";
            t = "gauge";
            help = ?"number of mints currently pending";
            labels = [];
            value = Nat.toText(pendingMints.size());
        });
        ms.add({
            name = "pending_mint_e8s";
            t = "gauge";
            help = ?"e8s value of mints currently pending";
            labels = [];
            value = Nat64.toText(pendingMintsE8s());
        });
        appendIter(ms, daily.metrics().vals());
        appendIter(ms, neuronsMetrics.vals());
        appendIter(ms, referralTracker.metrics().vals());
        appendIter(ms, scheduler.metrics().vals());
        appendIter(ms, staking.metrics().vals());
        appendIter(ms, withdrawals.metrics().vals());

        // For backwards compatibility in the metrics dashboard.

        switch (scheduler.getLastJobResult("dailyHeartbeat")) {
            case (null) {};
            case (?last) {
                ms.add({
                    name = "last_heartbeat_at";
                    t = "gauge";
                    help = ?"nanosecond timestamp of the last time heartbeat ran";
                    labels = [];
                    value = Int.toText(last.startedAt);
                });
            };
        };

        ms.toArray()
    };

    private func appendIter<X>(b: Buffer.Buffer<X>, iter: { next : () -> ?X }) {
        for (x in iter) { b.add(x) };
    };

    private func pendingMintsE8s(): Nat64 {
        var pendingMintE8s : Nat64 = 0;
        for (amount in pendingMints.vals()) {
            pendingMintE8s += amount;
        };
        pendingMintE8s
    };

    // ===== NEURON DISBURSAL FUNCTIONS =====

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

    // ===== REFERRAL FUNCTIONS =====

    public type ReferralStats = {
        code: Text;
        count: Nat;
        earned: Nat;
    };

    // Get a user's current referral stats. Used for the "Rewards" page.
    public shared(msg) func getReferralStats(): async ReferralStats {
        let code = await referralTracker.getCode(msg.caller);
        let stats = referralTracker.getStats(msg.caller);
        return {
            code = code;
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
        let icpReceipt = await ledger.transfer({
            memo : Nat64    = 0;
            from_subaccount = ?Blob.toArray(subaccount);
            to              = Blob.toArray(accountIdBlob());
            amount          = amount;
            fee             = fee;
            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
        });

        switch icpReceipt {
            case (#Err(_)) {
                return #Err(#TransferFailure);
            };
            case _ {};
        };

        // Use this to fulfill any pending withdrawals.
        ignore withdrawals.depositIcp(amount.e8s);

        // Mint the new tokens
        Debug.print("[Referrals.convert] user: " # debug_show(user));
        referralTracker.convert(user);
        ignore queueMint(user, amount.e8s);
        ignore flushMint(user);

        return #Ok(Nat64.toNat(amount.e8s));
    };

    // For safety, minting tokens is a two-step process. First we queue them
    // locally, in case the async mint call fails.
    private func queueMint(to : Principal, amount : Nat64) : Nat64 {
        let existing = Option.get(pendingMints.get(to), 0 : Nat64);
        let total = existing + amount;
        pendingMints.put(to, total);
        return total;
    };

    // Execute the pending mints for a specific user on the token canister.
    private func flushMint(to : Principal) : async TxReceipt {
        let total = Option.get(pendingMints.remove(to), 0 : Nat64);
        if (total == 0) {
            return #Err(#AmountTooSmall);
        };
        Debug.print("minting: " # debug_show(total) # " to " # debug_show(to));
        try {
            let result = await token.mint(to, Nat64.toNat(total));
            switch (result) {
                case (#Err(_)) {
                    // Mint failed, revert
                    pendingMints.put(to, total + Option.get(pendingMints.remove(to), 0 : Nat64));
                };
                case _ {};
            };
            result
        } catch (error) {
            // Mint failed, revert
            pendingMints.put(to, total + Option.get(pendingMints.remove(to), 0 : Nat64));
            #Err(#Other(Error.message(error)))
        }
    };

    // Execute all the pending mints on the token canister.
    private func flushAllMints() : async Result.Result<Nat, TxReceiptError> {
        let mints = Iter.toArray(
            Iter.map<(Principal, Nat64), (Principal, Nat)>(pendingMints.entries(), func((to, total)) {
                (to, Nat64.toNat(total))
            })
        );
        for ((to, total) in mints.vals()) {
            Debug.print("minting: " # debug_show(total) # " to " # debug_show(to));
        };
        pendingMints := TrieMap.TrieMap(Principal.equal, Principal.hash);
        try {
            switch (await token.mintAll(mints)) {
                case (#Err(err)) {
                    // Mint failed, revert
                    for ((to, amount) in mints.vals()) {
                        pendingMints.put(to, Nat64.fromNat(amount) + Option.get(pendingMints.get(to), 0 : Nat64));
                    };
                    #err(err)
                };
                case (#Ok(count)) {
                    #ok(count)
                };
            }
        } catch (error) {
            // Mint failed, revert
            for ((to, amount) in mints.vals()) {
                pendingMints.put(to, Nat64.fromNat(amount) + Option.get(pendingMints.get(to), 0 : Nat64));
            };
            #err(#Other(Error.message(error)))
        }
    };

    // ===== WITHDRAWAL FUNCTIONS =====

    // Show currently available ICP in this canister. This ICP retained for
    // withdrawals.
    public shared(msg) func availableBalance() : async Nat64 {
        _availableBalance()
    };

    private func _availableBalance() : Nat64 {
        let balance = cachedLedgerBalanceE8s;
        let reserved = withdrawals.reservedIcp();
        if (reserved >= balance) {
            0
        } else {
            balance - reserved
        }
    };

    // Update the canister's cached local balance
    private func refreshAvailableBalance() : async Nat64 {
        cachedLedgerBalanceE8s := (await ledger.account_balance({
            account = Blob.toArray(accountIdBlob());
        })).e8s;

        // See if we can fulfill any pending withdrawals.
        ignore withdrawals.depositIcp(_availableBalance());

        cachedLedgerBalanceE8s
    };

    // Datapoints representing available liquidity at a point in time.
    // `[(delay, amount)]`
    public type AvailableLiquidityGraph = [(Int, Nat64)];

    // Generate datapoints for a graph representing how much total liquidity is
    // available over time.
    public shared(msg) func availableLiquidityGraph(): async AvailableLiquidityGraph {
        let neurons = staking.availableLiquidityGraph();
        let b = Buffer.Buffer<(Int, Nat64)>(neurons.size()+1);
        b.add((0, _availableBalance()));
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

        // Burn the tokens from the user. This makes sure there is enough
        // balance for the user.
        let burn = await token.burnFor(user, Nat64.toNat(total));
        switch (burn) {
            case (#Err(err)) {
                return #err(#TokenError(err));
            };
            case (#Ok(_)) { };
        };

        // Check we have enough cash+neurons
        var availableCash = _availableBalance();
        // Minimum, 1 minute until withdrawals.depositIcp runs again.
        var delay: Int = 60;
        var availableNeurons: Nat64 = 0;
        if (total > availableCash) {
            let (d, a) = availableLiquidity(total - availableCash);
            delay := d;
            availableNeurons := a;
        };
        if (availableCash+availableNeurons < total) {
            // Refund the user's burnt tokens. In practice, this should never
            // happen, as cash+neurons should be >= totalTokens.
            ignore queueMint(user, total);
            ignore flushMint(user);
            return #err(#InsufficientLiquidity);
        };

        return #ok(withdrawals.createWithdrawal(user, total, delay));
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
            ignore refreshAvailableBalance();
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
        await daily.setInitialSnapshot()
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

    system func heartbeat() : async () {
        await scheduler.heartbeat(Time.now(), [
            {
                name = "flushAllMints";
                interval = 5 * second;
                function = func(now: Time.Time): async Result.Result<Any, Any> {
                    await flushAllMints()
                };
            },
            {
                name = "refreshAvailableBalance";
                interval = 1 * minute;
                function = func(now: Time.Time): async Result.Result<Any, Any> {
                    #ok(await refreshAvailableBalance())
                };
            },
            {
                name = "dailyHeartbeat";
                interval = 1 * day;
                function = func(now: Time.Time): async Result.Result<Any, Any> {
                    let root = Principal.fromActor(this);
                    #ok(await daily.run(
                        now,
                        root,
                        queueMint,
                        _availableBalance,
                        refreshAvailableBalance
                    ))
                };
            }
        ]);
    };

    // For manual recovery, in case of an issue with the most recent heartbeat.
    public shared(msg) func getLastJobResult(name: Text): async ?Scheduler.JobResult {
        owners.require(msg.caller);
        scheduler.getLastJobResult(name)
    };

    // For manual recovery, in case of an issue with the most recent heartbeat.
    public shared(msg) func setLastJobResult(name: Text, r: Scheduler.JobResult): async () {
        owners.require(msg.caller);
        scheduler.setLastJobResult(name, r)
    };

    // ===== UPGRADE FUNCTIONS =====

    system func preupgrade() {
        stablePendingMints := ?Iter.toArray(pendingMints.entries());

        // convert the buffer to a stable array
        appliedInterestEntries := appliedInterest.toArray();

        stableReferralData := referralTracker.preupgrade();

        stableNeuronsData := neurons.preupgrade();

        stableStakingData := staking.preupgrade();

        stableWithdrawalsData := withdrawals.preupgrade();

        stableSchedulerData := scheduler.preupgrade();

        stableDailyData := daily.preupgrade();

        stableOwners := owners.preupgrade();
    };

    system func postupgrade() {
        switch (stablePendingMints) {
            case (null) {};
            case (?entries) {
                pendingMints := TrieMap.fromEntries<Principal, Nat64>(entries.vals(), Principal.equal, Principal.hash);
                stablePendingMints := null;
            };
        };

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

        scheduler.postupgrade(stableSchedulerData);
        stableSchedulerData := null;

        daily.postupgrade(stableDailyData);
        stableDailyData := null;

        owners.postupgrade(stableOwners);
        stableOwners := null;
    };

};

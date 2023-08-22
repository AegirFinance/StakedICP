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

import Daily        "./Daily";
import ApplyInterest "./Daily/ApplyInterest";
import FlushPendingDeposits "./Daily/FlushPendingDeposits";
import SplitNewWithdrawalNeurons "./Daily/SplitNewWithdrawalNeurons";
import Scheduler    "./Scheduler";
import Hex          "./Hex";
import Neurons      "./Neurons";
import NNS          "./NNS";
import Owners       "./Owners";
import PendingTransfers "./PendingTransfers";
import Referrals    "./Referrals";
import Staking      "./Staking";
import Util         "./Util";
import Withdrawals  "./Withdrawals";
import Governance "../nns-governance";
import Ledger "../nns-ledger";
import Metrics      "../metrics/types";
import Token "../DIP20/motoko/src/token";
import TokenTypes "../DIP20/motoko/src/types";
import Account "../DIP20/motoko/src/account";

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
    // Start paused when we first deploy
    private stable var schedulerPaused : Bool = true;

    // Track any in-flight ledger.transfers so we can subtract it from our
    // available balance.
    private let pendingTransfers = PendingTransfers.Tracker();

    // State machine to track interest/maturity/neurons etc
    private let daily = Daily.Job({
        ledger = actor(Principal.toText(args.ledger));
        neurons = neurons;
        referralTracker = referralTracker;
        staking = staking;
        token = actor(Principal.toText(args.token));
        pendingTransfers = pendingTransfers;
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

    public type Neuron = {
        id : NeuronId;
        accountId : NNS.AccountIdentifier;
    };

    private stable var governance : Governance.Interface = actor(Principal.toText(args.governance));
    private stable var ledger : Ledger.Self = actor(Principal.toText(args.ledger));

    private stable var token : Token.Token = actor(Principal.toText(args.token));
    private let mintingSubaccount = Blob.fromArray([109, 105, 110, 116, 105, 110, 103]); // "minting" 

    private var pendingMints = TrieMap.TrieMap<Account.Account, Nat64>(Account.equal, Account.hash);
    private stable var stablePendingMints : ?[(Account.Account, Nat64)] = null;

    private stable var cachedLedgerBalanceE8s : Nat64 = 0;
    private stable var cachedTokenTotalSupply : Nat64 = 0;

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
        let stakingNeurons = staking.list();
        let b = Buffer.Buffer<{ id : Governance.NeuronId ; accountId : Text }>(stakingNeurons.size());
        for (neuron in stakingNeurons.vals()) {
            b.add({
                id = { id = neuron.id };
                accountId = NNS.accountIdToText(neuron.accountId);
            });
        };
        return b.toArray();
    };

    public shared(msg) func stakingNeuronBalances(): async [(Nat64, Nat64)] {
        staking.balances()
    };

    // Remove all staking neurons, and replace with the new list
    // Remove all withdrawal neurons
    // Reset totalMaturity to 0
    public shared(msg) func resetStakingNeurons(ids: [Nat64]): async Neurons.NeuronsResult {
        owners.require(msg.caller);
        staking.removeNeurons(staking.ids());
        withdrawals.removeNeurons(withdrawals.ids());
        daily.setTotalMaturity(0);
        let ns = await neurons.list(?ids);
        for (neuron in ns.vals()) {
            // No minting here as we are treating these neurons as
            // pre-existing.
            ignore staking.addOrRefresh(neuron);
        };
        return #ok(ns);
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
                    let canister = {owner = Principal.fromActor(this); subaccount = null};
                    ignore queueMint(canister, neuron.cachedNeuronStakeE8s);
                    ignore flushMint(canister);
                };
                #ok(neuron)
            };
        }
    };

    public shared(msg) func flushPendingDeposits(): async ?FlushPendingDeposits.FlushPendingDepositsResult {
        owners.require(msg.caller);
        await daily.flushPendingDeposits(Time.now(), refreshAvailableBalance)
    };

    public shared(msg) func proposalNeuron(): async ?Neurons.Neuron {
        null
    };

    public shared(msg) func setProposalNeuron(id: Nat64): async Neurons.NeuronResult {
        owners.require(msg.caller);
        #err(#Other("Proposal neuron is deprecated."))
    };

    private var _aprOverride : ?Nat64 = null;

    public shared(msg) func setAprOverride(microbips: ?Nat64) : async () {
        owners.require(msg.caller);
        _aprOverride := microbips;
    };

    // Getter for the current APR in microbips
    public query func aprMicrobips() : async Nat64 {
        switch (_aprOverride) {
            case (null) { daily.getMeanAprMicrobips() };
            case (?apr) { apr };
        }
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
        let exchange_rate = _exchangeRate();

        let ms = Buffer.Buffer<Metrics.Metric>(0);
        ms.add({
            name = "apr_microbips";
            t = "gauge";
            help = ?"latest apr in microbips";
            labels = [];
            value = Nat64.toText(daily.getMeanAprMicrobips());
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
            name = "available_balance";
            t = "gauge";
            help = ?"deposits canister available ICP balance";
            labels = [];
            value = Nat64.toText(_availableBalance());
        });
        ms.add({
            name = "cached_token_total_supply";
            t = "gauge";
            help = ?"cached token total supply";
            labels = [("token", "stICP"), ("canister", "deposits")];
            value = Nat64.toText(cachedTokenTotalSupply);
        });
        ms.add({
            name = "exchange_rate";
            t = "gauge";
            help = ?"total amounts used to calculate exchange rate";
            labels = [("token", "stICP")];
            value = Nat64.toText(exchange_rate.0);
        });
        ms.add({
            name = "exchange_rate";
            t = "gauge";
            help = ?"total amounts used to calculate exchange rate";
            labels = [("token", "ICP")];
            value = Nat64.toText(exchange_rate.1);
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

    // List all neurons being dissolved to fulfill withdrawals.
    public shared(msg) func listDissolvingNeurons(): async [Neurons.Neuron] {
        owners.require(msg.caller);
        withdrawals.listNeurons()
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
        referralTracker.touch(msg.caller, code, null);
        NNS.accountIdToText(NNS.accountIdFromPrincipal(Principal.fromActor(this), NNS.principalToSubaccount(msg.caller)));
    };

    // Same as getDepositAddress, but allows the canister owner to find it for
    // a specific user.
    public shared(msg) func getDepositAddressFor(user: Principal): async Text {
        owners.require(msg.caller);
        NNS.accountIdToText(NNS.accountIdFromPrincipal(Principal.fromActor(this), NNS.principalToSubaccount(user)));
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
        let subaccount = NNS.principalToSubaccount(user);
        let sourceAccount = NNS.accountIdFromPrincipal(Principal.fromActor(this), subaccount);

        // Check ledger for value
        let balance = await ledger.account_balance({ account = Blob.toArray(sourceAccount) });

        // Transfer to staking neuron
        if (Nat64.toNat(balance.e8s) <= minimumDeposit) {
            return #Err(#BalanceLow);
        };
        let fee = { e8s = Nat64.fromNat(icpFee) };
        let amount = { e8s = balance.e8s - fee.e8s };
        let now = Time.now();
        let icpReceipt = await ledger.transfer({
            memo : Nat64    = 0;
            from_subaccount = ?Blob.toArray(subaccount);
            to              = Blob.toArray(NNS.accountIdFromPrincipal(Principal.fromActor(this), NNS.defaultSubaccount()));
            amount          = amount;
            fee             = fee;
            created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(now)) };
        });

        switch icpReceipt {
            case (#Err(_)) {
                return #Err(#TransferFailure);
            };
            case _ {};
        };

        // Use this to fulfill any pending withdrawals.
        ignore withdrawals.depositIcp(amount.e8s, ?now);

        // Calculate how much stIcp to mint
        let (stIcp64, totalIcp64) = _exchangeRate();
        let stIcp = Nat64.toNat(stIcp64);
        let totalIcp = Nat64.toNat(totalIcp64);
        let depositAmount = Nat64.toNat(amount.e8s);
        // Formula to maintain the exchange rate:
        //   stIcp / totalIcp = toMintE8s / depositAmount
        //
        // And solve for toMintE8s:
        //   toMintE8s = (stIcp * depositAmount) / totalIcp
        //
        // Because we are working with Nats which have no decimals, we need to
        // do the multiplication first, to retain precision.
        let toMintE8s = Nat64.fromNat((stIcp * depositAmount) / totalIcp);

        // Mint the new tokens
        Debug.print("[Referrals.convert] user: " # debug_show(user));
        referralTracker.convert(user, ?now);
        let userAccount = {owner=user; subaccount=null};
        ignore queueMint(userAccount, toMintE8s);
        ignore flushMint(userAccount);

        return #Ok(Nat64.toNat(toMintE8s));
    };

    // For safety, minting tokens is a two-step process. First we queue them
    // locally, in case the async mint call fails.
    private func queueMint(to : Account.Account, amount : Nat64) : Nat64 {
        let existing = Option.get(pendingMints.get(to), 0 : Nat64);
        let total = existing + amount;
        pendingMints.put(to, total);
        return total;
    };

    // Execute the pending mints for a specific user on the token canister.
    private func flushMint(to : Account.Account) : async TokenTypes.ICRC1TransferResult {
        let amount = Option.get(pendingMints.remove(to), 0 : Nat64);
        if (amount == 0) {
            return #Err(#GenericError({error_code=0; message="amount too small"}))
        };
        Debug.print("minting: " # debug_show(amount) # " to " # debug_show(to));
        try {
            let result = await token.icrc1_transfer({
                from_subaccount = ?mintingSubaccount;
                to              = to;
                amount          = Nat64.toNat(amount);
                fee             = null;
                memo            = null;
                created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            });
            switch (result) {
                case (#Err(_)) {
                    // Mint failed, revert
                    pendingMints.put(to, amount + Option.get(pendingMints.remove(to), 0 : Nat64));
                };
                case _ {};
            };
            result
        } catch (error) {
            // Mint failed, revert
            pendingMints.put(to, amount + Option.get(pendingMints.remove(to), 0 : Nat64));
            #Err(#GenericError({error_code=1; message=Error.message(error)}))
        }
    };

    // Execute all the pending mints on the token canister.
    private func flushAllMints() : async Result.Result<Nat, Text> {
        let mints = Iter.toArray(
            Iter.map<(Account.Account, Nat64), (Account.Account, Nat)>(pendingMints.entries(), func((to, amount)) {
                (to, Nat64.toNat(amount))
            })
        );
        for ((to, amount) in mints.vals()) {
            Debug.print("minting: " # debug_show(amount) # " to " # debug_show(to));
        };
        pendingMints := TrieMap.TrieMap(Account.equal, Account.hash);
        try {
            switch (await token.mintAllAccounts(mints)) {
                case (#Err(err)) {
                    // Mint failed, revert
                    for ((to, amount) in mints.vals()) {
                        pendingMints.put(to, Nat64.fromNat(amount) + Option.get(pendingMints.get(to), 0 : Nat64));
                    };
                    #err(switch (err) {
                        case (#BadBurn(_)) { "amount too small" };
                        case (#BadFee(_)) { "incorrect fee" };
                        case (#InsufficientFunds(_)) { "insufficient funds" };
                        case (#TooOld) { "transaction too old" };
                        case (#CreatedInFuture(_)) { "transaction created in future" };
                        case (#Duplicate(_)) { "duplicate transaction" };
                        case (#TemporarilyUnavailable(_)) { "temporarily unavailable" };
                        case (#GenericError({ message })) { message };
                    })
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
            #err(Error.message(error))
        }
    };

    // ===== EXCHANGE RATE FUNCTIONS =====

    // exchangeRate returns (stICP, totalICP), so the client can calculate the
    // exchange rate
    public query func exchangeRate() : async (Nat64, Nat64) {
        _exchangeRate()
    };

    // _exchangeRate returns (stICP, totalICP) synchronously, so this contract
    // can calculate the exchange rate
    private func _exchangeRate() : (Nat64, Nat64) {
        let stIcp = cachedTokenTotalSupply;
        var totalIcp = _availableBalance();
        for ((id, b) in staking.balances().vals()) {
            totalIcp += b;
        };
        (stIcp, totalIcp)
    };

    private func refreshTokenTotalSupply() : async Nat64 {
        cachedTokenTotalSupply := Nat64.fromNat(await token.totalSupply());
        cachedTokenTotalSupply
    };

    // ===== WITHDRAWAL FUNCTIONS =====

    // Show currently available ICP in this canister. Minus ICP retained for
    // available withdrawals, and any ongoing outbound transfers.
    public shared(msg) func availableBalance() : async Nat64 {
        _availableBalance()
    };

    private func _availableBalance() : Nat64 {
        let balance = cachedLedgerBalanceE8s;
        // Withhold enough ICP for pending withdrawals and outbound transfers
        let reserved = withdrawals.reservedIcp() + pendingTransfers.reservedIcp();
        if (reserved >= balance) {
            0
        } else {
            balance - reserved
        }
    };

    // Update the canister's cached local balance.
    //
    // cachedLedgerBalanceE8s must always be <= actual icp balance. This ensures
    // outbound transfers cannot fail.
    //
    // We can never get a fully accurate view of the account_balance due to the
    // IC's asynchronous nature, but this is the closest we get. This is caused
    // by
    // https://internetcomputer.org/docs/current/references/ic-interface-spec#ordering_guarantees,
    // stating that message replies may be returned out of order. So you could
    // have a race condition where this balance is returned out of order with a
    // ledger.transfer.
    private func refreshAvailableBalance() : async Nat64 {
        // Take a snapshot of the completed transfers. We know that any
        // transfers present here will have been completed before we fetched
        // the ledger balance, therefore they will be reflected in the balance
        // we see from the ledger.
        let completedTransferIds = pendingTransfers.completedIds();

        // Go fetch the new balance.
        let account = Blob.toArray(NNS.accountIdFromPrincipal(Principal.fromActor(this), NNS.defaultSubaccount()));
        cachedLedgerBalanceE8s := (await ledger.account_balance({
            account = account;
        })).e8s;

        // Now that we have an up-to-date balance we can clear the record of
        // our known-completed transfers.
        //
        // Other transfers may have completed since we took the snapshot above,
        // but we don't know if they were included in the balance we fetched,
        // so we will be conservative, and leave them alone, to continue
        // withholding those funds until the next refresh.
        pendingTransfers.delete(completedTransferIds);

        // See if we can fulfill any pending withdrawals. We do this atomically
        // immediately so that the availableBalance doesn't fluctuate.
        ignore withdrawals.depositIcp(_availableBalance(), null);

        _availableBalance()
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

    // amount is in ICP e8s
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
    public shared(msg) func createWithdrawal(user: Account.Account, amount: Nat64) : async Result.Result<Withdrawals.Withdrawal, Withdrawals.WithdrawalsError> {
        assert(msg.caller == user.owner);

        // Calculate how much icp to pay out
        let (stIcp64, totalIcp64) = _exchangeRate();
        let stIcp = Nat64.toNat(stIcp64);
        let totalIcp = Nat64.toNat(totalIcp64);
        let burnAmount = Nat64.toNat(amount);
        assert(burnAmount <= stIcp);
        // Convert with the exchange rate:
        //   totalIcp / stIcp = toUnlockE8s / burnAmount
        //
        // And solve for toUnlockE8s:
        //   toUnlockE8s = burnAmount * (totalIcp / stIcp)
        //
        // Because we are working with Nats which have no decimals, we need to
        // do the multiplication first, to retain precision.
        assert(stIcp > 0);
        let toUnlockE8s = Nat64.fromNat((burnAmount * totalIcp) / stIcp);
        assert(toUnlockE8s > 0);

        // Burn the tokens from the user. This makes sure there is enough
        // balance for the user.
        // TODO: Figure out how to do this with ICRC1. Approve &
        // transferFrom flow
        let burn = await token.burnForAccount(user, Nat64.toNat(amount));
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
        if (toUnlockE8s > availableCash) {
            let (d, a) = availableLiquidity(toUnlockE8s - availableCash);
            delay := d;
            availableNeurons := a;
        };
        if (availableCash+availableNeurons < toUnlockE8s) {
            // Refund the user's burnt tokens. In practice, this should never
            // happen, as cash+neurons should be >= totalTokens.
            ignore queueMint(user, amount);
            ignore flushMint(user);
            return #err(#InsufficientLiquidity);
        };

        return #ok(withdrawals.createWithdrawal(user.owner, toUnlockE8s, delay));
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
        let toAddress = switch (NNS.accountIdFromText(to)) {
            case (#err(_)) {
                // Try to parse as a principal
                try {
                    NNS.accountIdFromPrincipal(Principal.fromText(to), NNS.defaultSubaccount())
                } catch (error) {
                    return #err(#InvalidAddress);
                };
            };
            case (#ok(toAddress)) {
                if (NNS.validateAccountIdentifier(toAddress)) {
                    toAddress
                } else {
                    return #err(#InvalidAddress);
                }
            };
        };

        // Check we think we have enough cash available to fulfill this.
        // We can't use _availableBalance here, because it subtracts out the
        // withdrawals.reservedICP, which is what we actually want to use for
        // this fulfillment.
        if (Nat64.min(cachedLedgerBalanceE8s, withdrawals.reservedIcp()) < amount + pendingTransfers.reservedIcp()) {
            return #err(#InsufficientLiquidity);
        };


        // Mark withdrawals as complete, and the balances as "disbursed"
        let {transferArgs; failure} = switch (withdrawals.completeWithdrawal(user, amount, toAddress)) {
            case (#err(err)) { return #err(err); };
            case (#ok(a)) { a };
        };

        // Mark the funds as unavailable while the transfer is pending.
        let transferId = pendingTransfers.add(amount);

        // Attempt the transfer, reverting if it fails.
        let result = try {
            let transfer = await ledger.transfer(transferArgs);
            switch (transfer) {
                case (#Ok(block)) {
                    pendingTransfers.success(transferId);
                    #ok(block)
                };
                case (#Err(#InsufficientFunds{})) {
                    // Not enough ICP in the contract
                    pendingTransfers.failure(transferId);
                    failure();
                    #err(#InsufficientLiquidity)
                };
                case (#Err(err)) {
                    pendingTransfers.failure(transferId);
                    failure();
                    #err(#TransferError(err))
                };
            }
        } catch (error) {
            pendingTransfers.failure(transferId);
            failure();
            #err(#Other(Error.message(error)))
        };

        // Queue a balance refresh.
        ignore refreshAvailableBalance();

        result
    };

    // List all withdrawals for a user.
    public shared(msg) func listWithdrawals(user: Principal) : async [Withdrawals.Withdrawal] {
        if (msg.caller != user) {
            owners.require(msg.caller);
        };
        return withdrawals.withdrawalsFor(user);
    };

    public shared(msg) func withdrawalsTotal() : async Nat64 {
        owners.require(msg.caller);
        return withdrawals.reservedIcp() + withdrawals.totalPending();
    };

    // ===== HELPER FUNCTIONS =====

    public shared(msg) func setInitialSnapshot(): async (Text, [(Account.Account, Nat)]) {
        owners.require(msg.caller);
        await daily.setInitialSnapshot()
    };

    public shared(msg) func getAppliedInterest(): async [ApplyInterest.ApplyInterestSummary] {
        owners.require(msg.caller);
        return daily.getAppliedInterest();
    };

    public shared(msg) func setAppliedInterest(elems: [ApplyInterest.ApplyInterestSummary]): async () {
        owners.require(msg.caller);
        daily.setAppliedInterest(elems);
    };

    public shared(msg) func getTotalMaturity(): async Nat64 {
        owners.require(msg.caller);
        return daily.getTotalMaturity();
    };

    public shared(msg) func setTotalMaturity(v: Nat64): async () {
        owners.require(msg.caller);
        daily.setTotalMaturity(v);
    };

    public shared(msg) func getReferralData(): async ?Referrals.UpgradeData {
        owners.require(msg.caller);
        return referralTracker.preupgrade();
    };

    public shared(msg) func setReferralData(data: ?Referrals.UpgradeData): async () {
        owners.require(msg.caller);
        return referralTracker.postupgrade(data);
    };

    public shared(msg) func neuronAccountId(controller: Principal, nonce: Nat64): async Text {
        owners.require(msg.caller);
        return NNS.accountIdToText(Util.neuronAccountId(args.governance, controller, nonce));
    };

    public shared(msg) func neuronAccountIdSub(controller: Principal, subaccount: Blob.Blob): async Text {
        owners.require(msg.caller);
        return NNS.accountIdToText(NNS.accountIdFromPrincipal(args.governance, subaccount));
    };

    // Called once/day by the external oracle
    // 1. Apply Interest
    //    a. Update cached neuron stakes (to figure out how much interest we gained today)
    //    b. Take a new holders snapshot for the next day
    //    c. Mint new tokens to holders
    //    d. Update the holders snapshot for tomorrow
    //    e. Log interest and update meanAprMicrobips
    // 2. Flush Pending Deposits
    //    a. Query token total supply & canister balance
    //    b. Fulfill pending deposits from canister balance if possible
    //    c. Deposit incoming ICP into neurons
    //    d. Refresh staking neuron balances & cache
    // 3. Split New Withdrawal Neurons
    //    a. Garbage-collect disbursed neurons from the withdrawal module tracking
    //       1. This should figure out which neurons *might* have been disbursed, and querying the
    //       governance canister to confirm their state. This will make it idempotent.
    //       2. If there are unknown dissolving neurons, they should be considered as new withdrawal
    //       neurons. This will make it idempotent.
    //    a. Query dissolving neurons total & pending total, to calculate dissolving target
    //    b. Return a list of which staking neurons to split and how much
    public shared(msg) func refreshNeuronsAndApplyInterest(): async [(Nat64, Nat64)] {
        owners.require(msg.caller);
        let now = Time.now();
        let root = {owner = Principal.fromActor(this); subaccount = null};
        let result = await daily.run(
            now,
            root,
            queueMint,
            refreshAvailableBalance
        );
        switch (result.2) {
            case (?#ok(neurons_to_split)) { neurons_to_split };
            case _ { [] };
        }
    };

    // ===== HEARTBEAT FUNCTIONS =====

    system func heartbeat() : async () {
        if schedulerPaused {
            return;
        };

        await scheduler.heartbeat(Time.now(), [
            {
                name = "flushAllMints";
                interval = 5 * second;
                function = func(now: Time.Time): async Result.Result<Any, Text> {
                    await flushAllMints()
                };
            },
            {
                name = "refreshAvailableBalance";
                interval = 1 * minute;
                function = func(now: Time.Time): async Result.Result<Any, Text> {
                    #ok(await refreshAvailableBalance())
                };
            },
            {
                name = "refreshTokenTotalSupply";
                interval = 1 * minute;
                function = func(now: Time.Time): async Result.Result<Any, Text> {
                    #ok(await refreshTokenTotalSupply())
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

    // So we can deploy and setup before the scheduler starts
    public shared(msg) func setSchedulerPaused(value: Bool): async () {
        owners.require(msg.caller);
        schedulerPaused := value;
    };

    public shared(msg) func getLastDailyJobResult(): async Daily.DailyResult {
        owners.require(msg.caller);
        daily.getResults()
    };

    public shared(msg) func getAppliedInterestMerges(): async [[(Nat64, Nat64, Neurons.NeuronResult)]] {
        owners.require(msg.caller);
        daily.getAppliedInterestMerges()
    };

    public shared(msg) func setTokenMintingAccount(): async () {
        owners.require(msg.caller);
        await token.setMintingAccount(?{
            owner = Principal.fromActor(this);
            subaccount = ?mintingSubaccount;
        })
    };

    public shared(msg) func accountIdFromPrincipal(to: Principal): async Text {
        owners.require(msg.caller);
        NNS.accountIdToText(
            NNS.accountIdFromPrincipal(
                to,
                NNS.defaultSubaccount()
            )
        )
    };

    // ===== UPGRADE FUNCTIONS =====

    system func preupgrade() {
        stablePendingMints := ?Iter.toArray(pendingMints.entries());

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
                pendingMints := TrieMap.fromEntries<Account.Account, Nat64>(entries.vals(), Account.equal, Account.hash);
                stablePendingMints := null;
            };
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

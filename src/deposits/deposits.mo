import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Order "mo:base/Order";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";

import Account      "./Account";
import Hex          "./Hex";
import Governance "Governance";
import Ledger "Ledger";
import LedgerCandid "LedgerCandid";
import Token "../token/token";

shared(init_msg) actor class Deposits(args: {
    governance: Principal;
    ledger: Principal;
    ledgerCandid: Principal;
    token: Principal;
    owners: [Principal];
    stakingNeuron: ?{ id : { id : Nat64 }; accountId : Text };
}) = this {

    type NeuronId = { id : Nat64; };

    type ApplyInterestResult = {
        timestamp : Time.Time;
        supply : {
            before : Ledger.Tokens;
            after : Ledger.Tokens;
        };
        applied : Ledger.Tokens;
        remainder : Ledger.Tokens;
        totalHolders: Nat;
    };

    type WithdrawPendingDepositsResult = {
      args : Ledger.TransferArgs;
      result : Ledger.TransferResult;
    };

    public type Invoice = {
      memo: Nat64;
      from: Principal;
      to: Text;
      state: InvoiceState;
      block: ?Nat64;
      createdAt : Time.Time;
      receivedAt : ?Time.Time;
    };

    public type InvoiceState = {
        #Waiting;
        #Received;
        #Staked;
    };

    public type StakingNeuron = {
        id : NeuronId;
        accountId : Account.AccountIdentifier;
    };

    private stable var governance : Governance.Interface = actor(Principal.toText(args.governance));
    private stable var ledger : Ledger.Self = actor(Principal.toText(args.ledger));
    private stable var ledgerCandid : LedgerCandid.Self = actor(Principal.toText(args.ledgerCandid));

    private stable var owners : [Principal] = args.owners;
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

    private stable var nextInvoiceId : Nat64 = 0;
    private stable var invoices : Trie.Trie<Nat64, Invoice> = Trie.empty();


    private stable var appliedInterestEntries : [ApplyInterestResult] = [];
    private var appliedInterest : Buffer.Buffer<ApplyInterestResult> = Buffer.Buffer(0);
    private stable var meanAprMicrobips : Nat64 = 0;

    private func isOwner(candidate : Principal) : Bool {
        let found = Array.find(owners, func(p : Principal) : Bool {
            Principal.equal(p, candidate)
        });
        found != null
    };

    private func requireOwner(candidate : Principal) {
        assert(isOwner(candidate));
    };

    public shared(msg) func addOwner(candidate: Principal) {
        requireOwner(msg.caller);
        owners := Array.append(owners, [candidate]);
    };

    public shared(msg) func removeOwner(candidate: Principal) {
        requireOwner(msg.caller);
        assert(owners.size() > 1); // Stop us from locking ourselves out.
        owners := Array.filter(owners, func(p : Principal) : Bool {
          not Principal.equal(p, candidate)
        });
    };

    public shared(msg) func setToken(_token: Principal) {
        requireOwner(msg.caller);
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

    public shared(msg) func setStakingNeuron(n: { id : NeuronId ; accountId : Text }) {
        requireOwner(msg.caller);
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

    private func balance() : async Ledger.Tokens {
        return await ledger.account_balance({
            account = Blob.toArray(accountIdBlob());
        });
    };

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

    public shared(msg) func applyInterest(interest: Nat, when: ?Time.Time) : async ApplyInterestResult {
        requireOwner(msg.caller);

        let now = Option.get(when, Time.now());

        let result = await applyInterestToToken(now, interest);

        appliedInterest.add(result);
        appliedInterest := sortBuffer(appliedInterest, sortInterestByTime);

        updateMeanAprMicrobips();

        return result;
    };

    private func getAllHolders(): async [(Principal, Nat)] {
        let info = await token.getTokenInfo();
        // *2 here is because this is not atomic, so if anyone joins in the
        // meantime.
        return await token.getHolders(0, info.holderNumber*2);
    };

    private func applyInterestToToken(now: Time.Time, interest: Nat): async ApplyInterestResult {
        let holders = await getAllHolders();

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
            };
        };
        assert(interest > 0);

        var remainder = interest;

        var mints : [(Principal, Nat)] = [];
        var afterSupply : Nat = 0;
        for (i in Iter.range(0, holders.size() - 1)) {
            let (to, balance) = holders[i];
            let share = (interest * balance) / beforeSupply;
            if (share > 0) {
                mints := Array.append(mints, [(to, share)]);
            };
            assert(share <= remainder);
            remainder -= share;
            afterSupply += balance + share;
        };
        assert(afterSupply >= beforeSupply);
        assert(interest >= remainder);
        assert(afterSupply == beforeSupply + interest - remainder);

        // Do the mints
        for ((to, share) in Array.vals(mints)) {
            Debug.print("minting: " # debug_show(share) # " to " # debug_show(to));

            let result = switch (await token.mint(to, share)) {
                case (#Err(_)) {
                    assert(false);
                    loop {};
                };
                case (#Ok(x)) { x };
            }
        };

        return {
            timestamp = now;
            supply = {
                before = { e8s = Nat64.fromNat(beforeSupply) };
                after = { e8s = Nat64.fromNat(afterSupply) };
            };
            applied = { e8s = Nat64.fromNat(afterSupply - beforeSupply) };
            remainder = { e8s = Nat64.fromNat(remainder) };
            totalHolders = holders.size();
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

        let microbips : Nat64 = 100_000_000;
        meanAprMicrobips := ((microbips * last.supply.after.e8s) / last.supply.before.e8s) - microbips;
        Debug.print("meanAprMicrobips: " # debug_show(meanAprMicrobips));
    };

    public query func aprMicrobips() : async Nat64 {
        return meanAprMicrobips;
    };

    // DEPRECATED: withdrawPendingDeposits is left, incase someone somehow
    // transfers to the canister instead of the neuron directly.
    public shared(msg) func withdrawPendingDeposits(to: Text) : async WithdrawPendingDepositsResult {
        requireOwner(msg.caller);

        let toBlob = switch (Account.fromText(to)) {
          case (#err(_)) {
            assert(false);
            loop {};
          };
          case (#ok(x)) { Blob.toArray(x) };
        };

        let pendingAmount = await balance();
        // TODO: Should we assert we have >1 icp to save on fees? or some smaller amount?
        assert(pendingAmount.e8s > 1_000_000);

        let fee = { e8s = 10_000 : Nat64 };
        let args : Ledger.TransferArgs = {
            memo            = 1; // TODO: Does this need to be something specific?
            amount          = { e8s = pendingAmount.e8s - fee.e8s };
            fee             = fee;
            from_subaccount = null;
            to              = toBlob;
            created_at_time = null;
        };
        let result = await ledger.transfer(args);

        return {
            args = args;
            result = result;
        };
    };

    public shared(msg) func createInvoice() : async Invoice {
        let to = await stakingNeuron();
        switch (to) {
            case (null) { P.unreachable() };
            case (?to) {
                nextInvoiceId += 1;

                let invoice : Invoice = {
                  memo = nextInvoiceId;
                  from = msg.caller;
                  to = to.accountId;
                  state = #Waiting;
                  block = null;
                  createdAt = Time.now();
                  receivedAt = null;
                };
                invoices := Trie.replace(invoices, invoiceKey(invoice.memo), Nat64.equal, ?invoice).0;
                return invoice;
            };
        }
    };

    public shared(msg) func getInvoice(memo: Nat64) : async ?Invoice {
        switch (Trie.find(invoices, invoiceKey(memo), Nat64.equal)) {
          case (null) {
            return null;
          };
          case (?invoice) {
            if (invoice.from != msg.caller and not isOwner(msg.caller)) {
              return null;
            } else {
              return ?invoice;
            }
          };
        }
    };

    // Create a trie key from a superhero identifier.
    private func invoiceKey(x : Nat64) : Trie.Key<Nat64> {
        return { hash = Hash.hash(Nat64.toNat(x)); key = x };
    };

    public type TransactionNotification = {
        memo : Nat64;
        block_height : Nat64;
    };

    // Handle deposits & mint token
    public shared(msg) func notify(notification : TransactionNotification) : async () {
      let found = Trie.find(invoices, invoiceKey(notification.memo), Nat64.equal);
      switch (found) {
        case (null) {
          // not found
          assert(false);
          loop {};
        };
        case (?invoice) {
          if (invoice.from != msg.caller and not isOwner(msg.caller)) {
            // can only notify on your own invoices.
            assert(false);
            loop {};
          };
          switch ((invoice.state, invoice.block)) {
            case ((#Waiting, null)) {
              let block = await ledgerCandid.block(notification.block_height);
              switch (block) {
                case (#Err(_)) {
                  assert(false);
                  loop {};
                };
                case (#Ok(r)) {
                  switch (r) {
                    case (#Err(_)) {
                      assert(false);
                      loop {};
                    };
                    case (#Ok(b)) {
                      // Verify the transaction is the right one
                      let transaction = b.transaction;
                      assert(transaction.memo == notification.memo);
                      let transfer = transaction.transfer;
                      switch (transfer) {
                        case (#Send(t)) {
                          // Verify the transfer went to this canister.
                          assert(Hex.equal(t.to, invoice.to));
                          // Mark this as done. This will be committed when we await the mint, below.
                          let newInvoice : Invoice = {
                            memo = invoice.memo;
                            from = invoice.from;
                            to = invoice.to;
                            state = #Received;
                            block = ?notification.block_height;
                            createdAt = invoice.createdAt;
                            receivedAt = ?Nat64.toNat(transaction.created_at_time.timestamp_nanos);
                          };

                          // Make sure the invoice hasn't changed since we talked to ledgerCandid.
                          let isUnchanged : Bool = Option.get(
                            Option.map(
                              Trie.find(invoices, invoiceKey(notification.memo), Nat64.equal),
                              func(found : Invoice) : Bool {
                                found.memo == invoice.memo
                                  and found.from == invoice.from
                                  and found.to == invoice.to
                                  and found.state == #Waiting
                                  and found.block == null
                                  and found.receivedAt == null
                              }
                            ),
                            false
                          );
                          if (isUnchanged != true) {
                            assert(false);
                            loop {};
                          };

                          invoices := Trie.replace(invoices, invoiceKey(invoice.memo), Nat64.equal, ?newInvoice).0;
                          // Disburse the new tokens
                          let result = await token.mint(invoice.from, Nat64.toNat(t.amount.e8s));

                          // Refresh the neuron balance, if we deposited directly
                          switch (await stakingNeuron()) {
                              case (null) {
                                  Debug.print("Staking neuron not configured for invoice: " # debug_show(invoice.memo));
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

                          return ();
                        };
                        case (_) {
                          assert(false);
                          loop {};
                        };
                      };
                    };
                  };
                };
              };
            };
            case (_) {
              // Already processed.
              return ();
            };
          };
        };
      };
      return ();
    };

    /*
    * upgrade functions
    */
    system func preupgrade() {
      // convert the buffer to a stable array
      appliedInterestEntries := appliedInterest.toArray();
    };

    system func postupgrade() {
      // convert the stable array back to a buffer.
      appliedInterest := Buffer.Buffer(appliedInterestEntries.size());
      for (x in appliedInterestEntries.vals()) {
        appliedInterest.add(x);
      };
    };
};

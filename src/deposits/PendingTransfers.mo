import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";

module {
    // Tracker tracks ledger.transfers which are in-progress, so that we can
    // subtract those from our cached balance.
    public class Tracker() {
        // Used to generate the next pendingTransfer id
        private var nextId: Nat = 0;
        // In-transit ledger.transfers we are currently awaiting.
        private var pending = TrieMap.TrieMap<Text, Nat64>(Text.equal, Text.hash);
        // Successful ledger.transfers. We withhold these funds until the next refresh.
        private var completed = TrieMap.TrieMap<Text, Nat64>(Text.equal, Text.hash);

        // Returns how much ICP we should withhold from the available balance
        public func reservedIcp(): Nat64 {
            var sum: Nat64 = 0;
            // Withhold funds for any outbound in-progress ledger.transfers we
            // are awaiting.
            for (t in pending.vals()) {
                sum += t;
            };
            // Continue withholding funds after a transfer succeeds until the
            // next time we refresh the ledger.account_balance.
            for (t in completed.vals()) {
                sum += t;
            };
            sum
        };

        // Add a new pending transfer
        public func add(amount: Nat64): Text {
            nextId += 1;
            let id = Nat.toText(nextId);
            pending.put(id, amount);
            id
        };

        // Transfer is complete. Keep the funds unavailable until the next time
        // we refresh the balance.
        public func success(id: Text) {
            switch (pending.remove(id)) {
                case (?amount) { completed.put(id, amount) };
                case (_) {};
            };
        };

        // Transfer failed. We still have the funds, so we can unlock them.
        public func failure(id: Text) {
            pending.delete(id);
        };

        // Return a snapshot of the currently completed transfers.
        public func completedIds(): [Text] {
            Iter.toArray(completed.keys())
        };

        // Once we know that a completed transfer has been included in the
        // balance we've received from the ledger, we can unlock the funds from
        // the available balance.
        public func delete(ids: [Text]) {
            for (id in ids.vals()) {
                completed.delete(id);
            };
        };
    }
}

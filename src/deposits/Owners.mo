import Principal "mo:base/Principal";
import TrieSet "mo:base/TrieSet";

module {
    public type UpgradeData = {
        #v1: {
            owners: [Principal];
        };
    };

    // "Owners" standardizes some permission checking logic from the other
    // modules to help prevent mistakes.
    public class Owners(initial : [Principal]) {
        private var owners = TrieSet.fromArray<Principal>(initial, Principal.hash, Principal.equal);

        // Check if the candidate is an owner
        public func is(candidate : Principal) : Bool {
            TrieSet.mem(owners, candidate, Principal.hash(candidate), Principal.equal)
        };

        // Assert that the candidate must be an owner
        public func require(candidate : Principal) {
            assert(is(candidate));
        };

        // Add the candidate to the set of owners. Can only be called by a
        // current owner.
        public func add(caller : Principal, candidate: Principal) {
            require(caller);
            owners := TrieSet.put(owners, candidate, Principal.hash(candidate), Principal.equal);
        };

        // Remove the candidate from the set of owners. Can only be called by a
        // current owner. Cannot remove the last owner from the set to prevent
        // locking ourselves out.
        public func remove(caller : Principal, candidate: Principal) {
            require(caller);
            assert(TrieSet.size(owners) > 1); // Stop us from locking ourselves out.
            owners := TrieSet.delete(owners, candidate, Principal.hash(candidate), Principal.equal);
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                owners = TrieSet.toArray(owners);
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    owners := TrieSet.fromArray(data.owners, Principal.hash, Principal.equal);
                };
                case (_) { return; };
            };
        };
    }
}

import Principal "mo:base/Principal";
import TrieSet "mo:base/TrieSet";

module {
    public type UpgradeData = {
        #v1: {
            owners: [Principal];
        };
    };

    public class Owners(initial : [Principal]) {
        private var owners = TrieSet.fromArray<Principal>(initial, Principal.hash, Principal.equal);

        public func is(candidate : Principal) : Bool {
            TrieSet.mem(owners, candidate, Principal.hash(candidate), Principal.equal)
        };

        public func require(candidate : Principal) {
            assert(is(candidate));
        };

        public func add(caller : Principal, candidate: Principal) {
            require(caller);
            owners := TrieSet.put(owners, candidate, Principal.hash(candidate), Principal.equal);
        };

        public func remove(caller : Principal, candidate: Principal) {
            require(caller);
            assert(TrieSet.size(owners) > 1); // Stop us from locking ourselves out.
            owners := TrieSet.delete(owners, candidate, Principal.hash(candidate), Principal.equal);
        };

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

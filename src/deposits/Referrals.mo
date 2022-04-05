import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

module {
    // TODO: Populate this
    public type UpgradeData = {
        #v1: {};
    };

    type Lead = {
        principal: Principal;
        affiliate: ?Principal;
        firstTouchAt: Time.Time;
        lastTouchAt: Time.Time;
        convertedAt: ?Time.Time;
    };

    type Payout = {
        createdAt: Time.Time;
        amount: Nat;
    };

    type Stats = {
        count: Nat;
        earned: Nat;
    };

    public class Tracker() {
        // 30 days
        private var lookback: Nat = 30*24*60*60*1_000_000_000;

        private var nextId : Nat = 0;
        private var codesByPrincipal = TrieMap.TrieMap<Principal, Text>(Principal.equal, Principal.hash);
        private var principalsByCode = TrieMap.TrieMap<Text, Principal>(Text.equal, Text.hash);
        private var leads            = TrieMap.TrieMap<Principal, Lead>(Principal.equal, Principal.hash);
        private var conversions      = TrieMap.TrieMap<Principal, Buffer.Buffer<Principal>>(Principal.equal, Principal.hash);
        private var payouts          = TrieMap.TrieMap<Principal, Buffer.Buffer<Payout>>(Principal.equal, Principal.hash);
        private var totals           = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);

        public func getCode(affiliate: Principal) : async Text {
            switch (codesByPrincipal.get(affiliate)) {
                case (?existing) { return existing };
                case (null) {
                    let generated = await generateCode();
                    codesByPrincipal.put(affiliate, generated);
                    principalsByCode.put(generated, affiliate);
                    return generated;
                };
            }
        };

        public func getStats(affiliate: Principal) : Stats {
            return {
                count = switch (conversions.get(affiliate)) {
                    case (null) { 0 : Nat };
                    case (?c) { c.size() };
                };
                earned = Option.get(totals.get(affiliate), 0 : Nat);
            };
        };

        // Generate the next 
        // TODO: Implement this with nice unique text code generation
        private func generateCode() : async Text {
            nextId := nextId + 1;
            return Nat.toText(nextId);
        };

        // record a touch event for this referred user. If they already have a
        // touch within the last 30 days, this is a no-op.
        public func touch(user: Principal, code: ?Text) {
            let now = Time.now();

            // Do we recognize the code?
            var newAffiliate : Principal = switch (Option.chain(code, principalsByCode.get)) {
                case (?a) {
                    // Prevent self-referral
                    if (user == a) {
                        return;
                    };
                    a
                };
                case (_) { return; };
            };

            // Look up the lead
            var lead = Option.get(leads.get(user), {
                principal = user;
                affiliate = ?newAffiliate;
                firstTouchAt = now;
                lastTouchAt = now;
                convertedAt = null;
            });

            // Have they already converted?
            if (Option.isSome(lead.convertedAt)) {
                return;
            };

            // Is their touch outside the lookback?
            var firstTouchAt = lead.firstTouchAt;
            var affiliate = lead.affiliate;
            if (Option.isNull(affiliate) or lead.firstTouchAt < (now - lookback)) {
                firstTouchAt := now;
                affiliate := ?newAffiliate;
            };

            // Add/Update it
            leads.put(user, {
                principal = user;
                affiliate = affiliate;
                firstTouchAt = firstTouchAt;
                // This always goes to "now"
                lastTouchAt = now;
                convertedAt = null;
            });
        };

        // record a conversion event for this referred user
        public func convert(user: Principal) {
            let now = Time.now();

            // Look up the lead
            let lead = Option.get(leads.get(user), {
                principal = user;
                affiliate = null;
                firstTouchAt = now;
                lastTouchAt = now;
                convertedAt = null;
            });


            // Have they already converted?
            if (Option.isSome(lead.convertedAt)) {
                return;
            };

            // Is their touch outside the lookback?
            var firstTouchAt = lead.firstTouchAt;
            var affiliate = lead.affiliate;
            if (lead.firstTouchAt < (now - lookback)) {
                // too old, no affiliate credit.
                firstTouchAt := now;
                affiliate := null;
            };

            // Update the lead
            leads.put(user, {
                principal = user;
                affiliate = affiliate;
                firstTouchAt = now;
                lastTouchAt = now;
                convertedAt = ?now;
            });

            // Add the conversion
            switch (lead.affiliate) {
                case (null) {};
                case (?affiliate) {
                    let c = Option.get(conversions.get(affiliate), Buffer.Buffer<Principal>(0));
                    c.add(user);
                    conversions.put(affiliate, c);
                };
            }
        };

        // record a payout event for this referred user
        public func payout(user: Principal, conversionValue: Nat): ?(Principal, Nat) {
            // Look up the lead
            let lead = switch (leads.get(user)) {
                case (null) { return null; };
                case (?lead) { lead };
            };

            // Have they converted yet?
            if (Option.isNull(lead.convertedAt)) {
                return null;
            };

            // figure out how much the affiliate gets
            // 1/4 of conversion value goes to affiliate
            let amount = conversionValue / 4;

            switch (lead.affiliate) {
                case (null) { return null; };
                case (?affiliate) {
                    // Add the payout
                    let p = Option.get(payouts.get(affiliate), Buffer.Buffer<Payout>(0));
                    p.add({ createdAt = Time.now(); amount = amount });
                    payouts.put(affiliate, p);

                    // Update their affiliate's total
                    let total = Option.get(totals.get(affiliate), 0 : Nat);
                    totals.put(affiliate, total+amount);

                    return ?(affiliate, amount);
                };
            };
        };

        public func preupgrade() : ?UpgradeData {
            // TODO: Implement this
            return null;
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            // TODO: Implement this
        };
    }
}

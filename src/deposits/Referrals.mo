import Buffer "mo:base/Buffer";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import Nanoid "./Nanoid";
import Metrics "../metrics/types";

module {
    public type UpgradeData = {
        #v1: {
            codes: [(Principal, Text)];
            leads: [Lead];
            conversions: [(Principal, [Principal])];
            payouts: [(Principal, [Payout])];
            totals: [(Principal, Nat)];
        };
    };

    type LeadMetrics = {
        converted: Bool;
        hasAffiliate: Bool;
        count: Nat;
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

    // The Referrals Tracker manages out referral program. It tracks leads,
    // conversions, earnings, and calculates how much an affiliate is owed when
    // there is a conversion. See the "Rewards" page.
    public class Tracker() {
        // 30 days
        private var second = 1_000_000_000;
        private var minute = 60*second;
        private var hour = 60*minute;
        private var day = 24*hour;
        private var lookback: Nat = 30*day;

        private var codesByPrincipal = TrieMap.TrieMap<Principal, Text>(Principal.equal, Principal.hash);
        private var principalsByCode = TrieMap.TrieMap<Text, Principal>(Text.equal, Text.hash);
        private var leads            = TrieMap.TrieMap<Principal, Lead>(Principal.equal, Principal.hash);
        private var conversions      = TrieMap.TrieMap<Principal, Buffer.Buffer<Principal>>(Principal.equal, Principal.hash);
        private var payouts          = TrieMap.TrieMap<Principal, Buffer.Buffer<Payout>>(Principal.equal, Principal.hash);
        private var totals           = TrieMap.TrieMap<Principal, Nat>(Principal.equal, Principal.hash);

        public func metrics(): [Metrics.Metric] {
            let ms = Buffer.Buffer<Metrics.Metric>(2);

            for ({converted; hasAffiliate; count} in Iter.fromArray(leadMetrics())) {
                ms.add({
                    name = "referral_leads_count";
                    t = "gauge";
                    help = ?"number of referral leads by state";
                    labels = [
                        ("converted", Bool.toText(converted)),
                        ("hasAffiliate", Bool.toText(hasAffiliate)),
                    ];
                    value = Nat.toText(count);
                });
            };

            ms.add({
                name = "referral_affiliates_count";
                t = "gauge";
                help = ?"number of affiliates who have 1+ referred users";
                labels = [];
                value = Nat.toText(conversions.size());
            });
            ms.add({
                name = "referral_payouts_sum";
                t = "gauge";
                help = ?"total e8s paid out to affiliates";
                labels = [];
                value = Nat.toText(payoutsE8s());
            });
            ms.toArray()
        };

        private func leadMetrics(): [LeadMetrics] {
            var unconvertedNoAffiliate: Nat = 0;
            var convertedNoAffiliate: Nat = 0;
            var unconvertedAffiliate: Nat = 0;
            var convertedAffiliate: Nat = 0;
            for (lead in leads.vals()) {
                switch (lead.convertedAt, lead.affiliate) {
                    case (null, null) {
                        unconvertedNoAffiliate += 1;
                    };
                    case (?c, null) {
                        convertedNoAffiliate += 1;
                    };
                    case (null, ?a) {
                        unconvertedAffiliate += 1;
                    };
                    case (?c, ?a) {
                        convertedAffiliate += 1;
                    };
                };
            };
            return [
                {converted = false; hasAffiliate = false; count = unconvertedNoAffiliate},
                {converted = true; hasAffiliate = false; count = convertedNoAffiliate},
                {converted = false; hasAffiliate = true; count = unconvertedAffiliate},
                {converted = true; hasAffiliate = true; count = convertedAffiliate},
            ];
        };

        private func payoutsE8s(): Nat {
            var sum : Nat = 0;
            for (amount in totals.vals()) {
                sum += amount;
            };
            return sum;
        };

        // Get the code for an affiliate. Codes are randomly generated, so the
        // first time this is called for an affiliate it generates a new code
        // and stores it for them.
        public func getCode(affiliate: Principal) : async Text {
            switch (codesByPrincipal.get(affiliate)) {
                case (?existing) { return existing };
                case (null) {
                    var generated = await Nanoid.new();
                    while (Option.isSome(principalsByCode.get(generated))) {
                        // Re-generate if there's a collision.
                        generated := await Nanoid.new();
                    };
                    // check we didn't generate one in the meantime.
                    let newCode = Option.get(codesByPrincipal.get(affiliate), generated);
                    codesByPrincipal.put(affiliate, newCode);
                    principalsByCode.put(newCode, affiliate);
                    return newCode;
                };
            }
        };

        // Get the current conversion and earning stats for an affiliate (for
        // the "Rewards" page).
        public func getStats(affiliate: Principal) : Stats {
            return {
                count = switch (conversions.get(affiliate)) {
                    case (null) { 0 : Nat };
                    case (?c) { c.size() };
                };
                earned = Option.get(totals.get(affiliate), 0 : Nat);
            };
        };

        // Record a touch event for this referred user. If they already have a
        // touch within the last 30 days, this is a no-op.
        public func touch(user: Principal, code: ?Text, at: ?Time.Time) {
            let now = Option.get(at, Time.now());

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

        // Record a conversion event for this referred user. This permanently
        // associates them with their affiliate if it is still within the
        // conversion lookback window.
        public func convert(user: Principal, at: ?Time.Time) {
            let now = Option.get(at, Time.now());

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

        // Record a payout event for this referred user. e.g. the user earning
        // interest. This calculates how much the affiliate is owed.
        // conversionValue should be the amount earned by the protocol from
        // this user.
        public func payout(user: Principal, conversionValue: Nat, at: ?Time.Time): ?(Principal, Nat) {
            let now = Option.get(at, Time.now());
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
            // conversionValue is the protocol's 10% cut, so figure out 2.5%.
            let amount = conversionValue / 4;

            switch (lead.affiliate) {
                case (null) { return null; };
                case (?affiliate) {
                    // Add the payout
                    let p = Option.get(payouts.get(affiliate), Buffer.Buffer<Payout>(0));
                    // See if we can merge this into their latest payout (if the timestamp is the same)
                    let record = Option.get(p.removeLast(), { createdAt = now; amount = 0 });
                    p.add({ createdAt = now; amount = record.amount + amount});

                    payouts.put(affiliate, p);

                    // Update their affiliate's total
                    let total = Option.get(totals.get(affiliate), 0 : Nat);
                    totals.put(affiliate, total+amount);

                    return ?(affiliate, amount);
                };
            };
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                codes = Iter.toArray(codesByPrincipal.entries());
                leads = Iter.toArray(leads.vals());
                conversions = Iter.toArray(
                    TrieMap.map<Principal, Buffer.Buffer<Principal>, [Principal]>(
                        conversions,
                        Principal.equal,
                        Principal.hash,
                        func(p, cs) { cs.toArray() }
                    ).entries()
                );
                payouts = Iter.toArray(
                    TrieMap.map<Principal, Buffer.Buffer<Payout>, [Payout]>(
                        payouts,
                        Principal.equal,
                        Principal.hash,
                        func(p, ps) { ps.toArray() }
                    ).entries()
                );
                totals = Iter.toArray(totals.entries());
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    for ((principal, code) in Iter.fromArray(data.codes)) {
                        codesByPrincipal.put(principal, code);
                        principalsByCode.put(code, principal);
                    };

                    for (lead in Iter.fromArray(data.leads)) {
                        leads.put(lead.principal, lead);
                    };

                    for ((affiliate, referreds) in Iter.fromArray(data.conversions)) {
                        let refs = Buffer.Buffer<Principal>(referreds.size());
                        for (r in Iter.fromArray(referreds)) {
                            refs.add(r);
                        };
                        conversions.put(affiliate, refs);
                    };

                    for ((affiliate, ps) in Iter.fromArray(data.payouts)) {
                        let pbuf = Buffer.Buffer<Payout>(ps.size());
                        for (p in Iter.fromArray(ps)) {
                            pbuf.add(p);
                        };
                        payouts.put(affiliate, pbuf);
                    };


                    for ((affiliate, total) in Iter.fromArray(data.totals)) {
                        totals.put(affiliate, total);
                    };
                };
                case (_) { return; };
            };
        };
    }
}

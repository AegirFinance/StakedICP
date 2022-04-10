import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Deposits "../deposits/deposits";
import Referrals "../deposits/Referrals";
import Token "../DIP20/motoko/src/token";

shared(init_msg) actor class Metrics(args: {
    deposits: Principal;
    token: Principal;
    auth: ?Text;
}) = this {

    private stable var deposits : Deposits.Deposits = actor(Principal.toText(args.deposits));
    private stable var token : Token.Token = actor(Principal.toText(args.token));

    private stable var depositsMetrics : ?DepositsMetrics = null;
    private stable var tokenInfo : ?TokenInfo = null;
    private stable var lastUpdatedAt : ?Time.Time = null;

    private var errors: Buffer.Buffer<(Time.Time, Text, Error)> = Buffer.Buffer(0);

    type HeaderField = ( Text, Text );

    type HttpRequest = object {
        method: Text;
        url: Text;
        headers: [HeaderField];
        body: Blob;
    };

    type HttpResponse = object {
        status_code: Nat16;
        headers: [HeaderField];
        body: Blob;
    };

    type TokenInfo = {
        metadata: { totalSupply : Nat };
        historySize: Nat;
        holderNumber: Nat;
        cycles: Nat;
    };

    public type DepositsMetrics = {
        aprMicrobips: Nat64;
        balances: [(Text, Nat64)];
        stakingNeuronBalance: ?Nat64;
        referralAffiliatesCount: Nat;
        referralLeads: [Referrals.LeadMetrics];
        referralPayoutsSum: Nat;
    };

    public query func http_request(request: HttpRequest) : async HttpResponse {
        let headers : [HeaderField] = [("Content-Type", "text/plain"), ("WWW-Authenticate", "Basic realm=\"Metrics\", charset=\"UTF-8\"")];
        switch (args.auth) {
            case (null) { };
            case (?auth) {
                var found = "";
                for ((key, value) in request.headers.vals()) {
                    if (key == "authorization") {
                        found := value;
                    }
                };

                let expected = "Basic " # auth;
                if (found != expected) {
                    return {
                        status_code = 401;
                        headers = headers;
                        body = Text.encodeUtf8("Not authorized.");
                    };
                }
            };
        };

        switch (request.url) {
            case ("/metrics") {
                return metrics();
            };
            case ("/errors") {
                return showErrors();
            };
            case (_) {
                return {
                    status_code = 404;
                    headers = headers;
                    body = Text.encodeUtf8("Not found");
                };
            };
        };
    };

    private func metrics() : HttpResponse {
        let metrics: Buffer.Buffer<Text> = Buffer.Buffer(0);

        switch (depositsMetrics) {
            case (null) { };
            case (?depositsMetrics) {
                metrics.add("# TYPE apr_microbips gauge");
                metrics.add("# HELP apr_microbips latest apr in microbips");
                metrics.add("apr_microbips " # Nat64.toText(depositsMetrics.aprMicrobips));

                metrics.add("# TYPE canister_balance_e8s gauge");
                metrics.add("# HELP canister_balance_e8s canister balance for a token in e8s");
                for ((token, balance) in Iter.fromArray(depositsMetrics.balances)) {
                    metrics.add("canister_balance_e8s{token=\"" # token # "\",canister=\"deposits\"} " # Nat64.toText(balance));
                };


                switch (depositsMetrics.stakingNeuronBalance) {
                    case (null) {};
                    case (?b) {
                        metrics.add("# TYPE neuron_balance_e8s gauge");
                        metrics.add("# HELP neuron_balance_e8s e8s balance of the staking neuron");
                        metrics.add("neuron_balance_e8s " # Nat64.toText(b));
                    };
                };


                metrics.add("# TYPE referral_leads_count gauge");
                metrics.add("# HELP referral_leads_count number of referral leads by state");
                for ({converted; hasAffiliate; count} in Iter.fromArray(depositsMetrics.referralLeads)) {
                    metrics.add("referral_leads_count{converted=\"" #  Bool.toText(converted) #  "\", hasAffiliate=\"" # Bool.toText(hasAffiliate) # "\"} " # Nat.toText(count));
                };

                metrics.add("# TYPE referral_affiliates_count gauge");
                metrics.add("# HELP referral_affiliates_count number of affiliates who have 1+ referred users");
                metrics.add("referral_affiliates_count " # Nat.toText(depositsMetrics.referralAffiliatesCount));

                metrics.add("# TYPE referral_payouts_sum gauge");
                metrics.add("# HELP referral_payouts_sum number of referral leads by state");
                metrics.add("referral_payouts_sum " # Nat.toText(depositsMetrics.referralPayoutsSum));
            };
        };

        switch (tokenInfo) {
            case (null) { };
            case (?info) {
                metrics.add("# TYPE token_supply_e8s gauge");
                metrics.add("# HELP token_supply_e8s e8s sum of the current token supply");
                metrics.add("token_supply_e8s " # Nat.toText(info.metadata.totalSupply));

                metrics.add("# TYPE token_transactions gauge");
                metrics.add("# HELP token_transactions total number of token transactions");
                metrics.add("token_transactions " # Nat.toText(info.historySize));

                metrics.add("# TYPE token_holders gauge");
                metrics.add("# HELP token_holders current number of token holders");
                metrics.add("token_holders " # Nat.toText(info.holderNumber));

                metrics.add("# TYPE canister_balance_e8s gauge");
                metrics.add("# HELP canister_balance_e8s canister balance for a token in e8s");
                metrics.add("canister_balance_e8s{token=\"cycles\",canister=\"token\"} " # Nat.toText(info.cycles));
            };
        };

        metrics.add("# TYPE canister_balance_e8s gauge");
        metrics.add("# HELP canister_balance_e8s canister balance for a token in e8s");
        metrics.add("canister_balance_e8s{token=\"cycles\",canister=\"metrics\"} " # Nat.toText(ExperimentalCycles.balance()));

        switch (lastUpdatedAt) {
            case (null) { };
            case (?lastUpdatedAt) {
                metrics.add("# TYPE last_updated_at gauge");
                metrics.add("# HELP last_updated_at timestamp in ns, of last time the metrics were updated");
                metrics.add("last_updated_at " # Int.toText(lastUpdatedAt));
            };
        };

        let body = Text.join("\n", metrics.vals());
        return {
            status_code = 200;
            headers = [("Content-Type", "text/plain")];
            body = Text.encodeUtf8(body);
        };
    };

    private func showErrors() : HttpResponse {
        let output: Buffer.Buffer<Text> = Buffer.Buffer(0);

        for ((time, key, error) in errors.vals()) {
            output.add(debug_show(time) # "," # key # "," # Error.message(error));
        };

        let body = Text.join("\n", output.vals());
        return {
            status_code = 200;
            headers = [("Content-Type", "text/plain")];
            body = Text.encodeUtf8(body);
        };
    };

    system func heartbeat() : async () {
        // Only fire once per minute.
        let second = 1000_000_000;
        let now = Time.now();
        let elapsedSeconds = (now - Option.get(lastUpdatedAt, (now - (60*second)))) / second;
        if (elapsedSeconds < 60) {
            return ();
        };

        let depositsMetrics = refreshDepositsMetrics();
        let tokenInfo = refreshTokenInfo();

        await depositsMetrics;
        await tokenInfo;

        lastUpdatedAt := ?now;
    };

    private func refreshDepositsMetrics() : async () {
        try {
            depositsMetrics := ?(await deposits.metrics());
        } catch (e) {
            errors.add((Time.now(), "deposits-metrics", e));
        };
    };

    private func refreshTokenInfo() : async () {
        try {
            tokenInfo := ?(await token.getTokenInfo());
        } catch (e) {
            errors.add((Time.now(), "token-info", e));
        };
    };

};

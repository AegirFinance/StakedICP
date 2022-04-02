import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Account "../deposits/Account";
import Deposits "../deposits/deposits";
import Token "../DIP20/motoko/src/token";
import Ledger "canister:ledger";

shared(init_msg) actor class Metrics(args: {
    deposits: Principal;
    token: Principal;
    auth: ?Text;
}) = this {

    private stable var deposits : Deposits.Deposits = actor(Principal.toText(args.deposits));
    private stable var token : Token.Token = actor(Principal.toText(args.token));

    private stable var neuronBalanceE8s : ?Nat64 = null;
    private stable var aprMicrobips : ?Nat64 = null;
    private stable var invoices : ?[(Text, Nat64)] = null;
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

        // Get the neuron balance
        switch (neuronBalanceE8s) {
            case (null) { };
            case (?neuronBalanceE8s) {
                metrics.add("# TYPE neuron_balance_e8s gauge");
                metrics.add("# HELP neuron_balance_e8s e8s balance of the staking neuron");
                metrics.add("neuron_balance_e8s " # Nat64.toText(neuronBalanceE8s));
            };
        };

        switch (aprMicrobips) {
            case (null) { };
            case (?aprMicrobips) {
                metrics.add("# TYPE apr_microbips gauge");
                metrics.add("# HELP apr_microbips latest apr in microbips");
                metrics.add("apr_microbips " # Nat64.toText(aprMicrobips));
            };
        };

        switch (invoices) {
            case (null) { };
            case (?invoices) {
                metrics.add("# TYPE invoices gauge");
                metrics.add("# HELP invoices total number of invoices by state");
                for ((state, count) in invoices.vals()) {
                    metrics.add("invoices{state=\"" # state # "\"} " # Nat64.toText(count));
                }
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

        let balance = refreshStakingNeuronBalance();
        let apr = refreshAprMicrobips();
        let tokenInfo = refreshTokenInfo();

        await balance;
        await apr;
        await tokenInfo;

        lastUpdatedAt := ?now;
    };

    private func refreshStakingNeuronBalance() : async () {
        try {
            neuronBalanceE8s := await deposits.stakingNeuronBalance();
        } catch (e) {
            errors.add((Time.now(), "staking-neuron-balance", e));
        };
    };

    private func refreshAprMicrobips() : async () {
        try {
            aprMicrobips := ?(await deposits.aprMicrobips());
        } catch (e) {
            errors.add((Time.now(), "apr-microbips", e));
        };
    };

    private func refreshInvoices() : async () {
        try {
            invoices := ?(await deposits.invoicesByState());
        } catch (e) {
            errors.add((Time.now(), "invoices", e));
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

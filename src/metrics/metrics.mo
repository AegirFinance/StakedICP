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

import Types "./types";
import Deposits "../deposits/deposits";
import Token "../DIP20/motoko/src/token";

shared(init_msg) actor class Metrics(args: {
    deposits: Principal;
    token: Principal;
    auth: ?Text;
}) = this {

    private stable var deposits : Deposits.Deposits = actor(Principal.toText(args.deposits));
    private stable var token : Token.Token = actor(Principal.toText(args.token));

    private stable var depositsMetrics : ?[Types.Metric] = null;
    private stable var tokenInfo : ?TokenInfo = null;
    private stable var lastUpdatedAt : ?Time.Time = null;

    private var errors: Buffer.Buffer<(Time.Time, Text, Error)> = Buffer.Buffer(0);

    type HeaderField = ( Text, Text );

    type Token = {};

    type StreamingCallbackHttpResponse = {
        body : Blob;
        token : Token;
    };

    type StreamingStrategy = {
        #Callback : {
          callback : shared Token -> async StreamingCallbackHttpResponse;
          token : Token;
        };
    };

    type HttpRequest = object {
        method: Text;
        url: Text;
        headers: [HeaderField];
        body: Blob;
    };

    type HttpResponse = {
        status_code: Nat16;
        headers: [HeaderField];
        body: Blob;
        streaming_strategy: ?StreamingStrategy;
        upgrade: Bool;
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
                        streaming_strategy = null;
                        upgrade = false;
                    };
                }
            };
        };

        switch (Text.split(request.url, #text("?")).next()) {
            case (?"/metrics") {
                return metrics(true);
            };
            case (?"/errors") {
                return showErrors();
            };
            case (_) {
                return {
                    status_code = 404;
                    headers = headers;
                    body = Text.encodeUtf8("Not found");
                    streaming_strategy = null;
                    upgrade = false;
                };
            };
        };
    };

    public shared func http_request_update(request : HttpRequest) : async HttpResponse {
        let resp = metrics(false);
        ignore refreshMetrics();
        return resp;
    };

    private func metrics(upgrade: Bool) : HttpResponse {
        let lines: Buffer.Buffer<Text> = Buffer.Buffer(0);

        switch (depositsMetrics) {
            case (null) { };
            case (?ms) {
                for (m in ms.vals()) {
                    lines.add(renderMetric(m));
                };
            };
        };

        switch (tokenInfo) {
            case (null) { };
            case (?info) {
                lines.add(renderMetric({
                    name = "token_supply_e8s";
                    t = "gauge";
                    help = ?"e8s sum of the current token supply";
                    labels = [];
                    value = Nat.toText(info.metadata.totalSupply);
                }));

                lines.add(renderMetric({
                    name = "token_transactions";
                    t = "gauge";
                    help = ?"total number of token transactions";
                    labels = [];
                    value = Nat.toText(info.historySize);
                }));

                lines.add(renderMetric({
                    name = "token_holders";
                    t = "gauge";
                    help = ?"current number of token holders";
                    labels = [];
                    value = Nat.toText(info.holderNumber);
                }));

                lines.add(renderMetric({
                    name = "canister_balance_e8s";
                    t = "gauge";
                    help = ?"canister balance for a token in e8s";
                    labels = [("token", "cycles"), ("canister", "token")];
                    value = Nat.toText(info.cycles);
                }));
            };
        };

        lines.add(renderMetric({
            name = "canister_balance_e8s";
            t = "gauge";
            help = ?"canister balance for a token in e8s";
            labels = [("token", "cycles"), ("canister", "metrics")];
            value = Nat.toText(ExperimentalCycles.balance());
        }));

        switch (lastUpdatedAt) {
            case (null) { };
            case (?lastUpdatedAt) {
                lines.add(renderMetric({
                    name = "last_updated_at";
                    t = "gauge";
                    help = ?"timestamp in ns, of last time the metrics were updated";
                    labels = [];
                    value = Int.toText(lastUpdatedAt);
                }));
            };
        };

        let body = Text.join("\n", lines.vals());
        return {
            status_code = 200;
            headers = [("Content-Type", "text/plain")];
            body = Text.encodeUtf8(body);
            streaming_strategy = null;
            upgrade = upgrade;
        };
    };

    private func renderMetric({name; t; help; value; labels}: Types.Metric): Text {
        let lines = Buffer.Buffer<Text>(3);
        lines.add("# TYPE " # name # " " # t);
        switch (help) {
            case (null) {};
            case (?h) {
                lines.add("# HELP " # name # " " # h);
            };
        };
        let labelsText = "{" # Text.join(",", Iter.map<(Text, Text), Text>(
                    labels.vals(),
                    func((k, v)) { k # "=\"" # v # "\"" }
                    )) # "}";
        lines.add(name # labelsText # " " # value);
        return Text.join("\n", lines.vals());
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
            streaming_strategy = null;
            upgrade = false;
        };
    };

    private func refreshMetrics() : async () {
        // Only fire once per 30 seconds.
        let second = 1000_000_000;
        let now = Time.now();
        let elapsedSeconds = (now - Option.get(lastUpdatedAt, (now - (60*second)))) / second;
        if (elapsedSeconds < 30) {
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

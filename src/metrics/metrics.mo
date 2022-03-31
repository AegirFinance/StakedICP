import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
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
}) = this {

    private stable var deposits : Deposits.Deposits = actor(Principal.toText(args.deposits));
    private stable var token : Token.Token = actor(Principal.toText(args.token));

    private stable var neuronBalanceE8s : ?Nat64 = null;
    private stable var aprMicrobips : ?Nat64 = null;
    private stable var tokenInfo : ?TokenInfo = null;

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

        let body = Text.join("\n", metrics.vals());
        return {
            status_code = 200;
            headers = [("Content-Type", "text/plain")];
            body = Text.encodeUtf8(body);
        };
    };

    system func heartbeat() : async () {
        neuronBalanceE8s := await deposits.stakingNeuronBalance();
        aprMicrobips := ?(await deposits.aprMicrobips());
        tokenInfo := ?(await token.getTokenInfo());
    };
};

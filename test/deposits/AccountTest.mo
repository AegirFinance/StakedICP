import Account "mo:deposits/Account";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";

import Suite "mo:matchers/Suite";
import T "mo:matchers/Testable";
import M "mo:matchers/Matchers";

let nat8Testable : T.Testable<Nat8> = {
    display = func (nat : Nat8) : Text = Nat8.toText(nat);
    equals = func (n1 : Nat8, n2 : Nat8) : Bool = n1 == n2
};

let {run;suite;test} = Suite;
run(
    suite("Account", [
        test(
            "defaultSubaccount",
            Blob.toArray(Account.defaultSubaccount()),
            M.equals(T.array<Nat8>(nat8Testable, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
        )
    ])
);

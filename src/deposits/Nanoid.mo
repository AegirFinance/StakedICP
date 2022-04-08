import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Random "mo:base/Random";
import Text "mo:base/Text";

module {
    private let defaultAlphabet = "_-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    private let defaultAlphabetMap : [Nat32] = [
         95,  45,  48,  49,  50,  51,  52,  53,
         54,  55,  56,  57,  65,  66,  67,  68,
         69,  70,  71,  72,  73,  74,  75,  76,
         77,  78,  79,  80,  81,  82,  83,  84,
         85,  86,  87,  88,  89,  90,  97,  98,
         99, 100, 101, 102, 103, 104, 105, 106,
        107, 108, 109, 110, 111, 112, 113, 114,
        115, 116, 117, 118, 119, 120, 121, 122,
    ];
	private let defaultSize = 21;

    // new generates a nanoId
    public func new() : async Text {
        // gives initial 32 bytes of entropy
        var f = Random.Finite(await Random.blob());

        var id = "";
        var i = 0;
        while (i < defaultSize) {
            switch (f.byte()) {
                case (null) {
                    // Need more entropy
                    f := Random.Finite(await Random.blob());
                };
                case (?byte) {
                    id := id # Char.toText(Char.fromNat32(defaultAlphabetMap[Nat8.toNat(byte&63)]));
                    i += 1;
                };
            };
        };
        return id;
    };
}

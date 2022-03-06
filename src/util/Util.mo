import AId "mo:principal/blob/AccountIdentifier";
import Array "mo:base/Array";
import Binary "mo:encoding/Binary";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import SHA256 "mo:sha/SHA256";

module {
    public func neuronSubaccount(controller : Principal, nonce : Nat64) : [Nat8] {
       var arr : [Nat8] = [
           0x0c, 0x6e, 0x65, 0x75,
           0x72, 0x6f, 0x6e, 0x2d,
           0x73, 0x74, 0x61, 0x6b,
           0x65
       ];
       
       arr := Array.append<Nat8>(arr, Blob.toArray(Principal.toBlob(controller)));
       arr := Array.append<Nat8>(arr, Binary.BigEndian.fromNat64(nonce));

       return SHA256.sum256(arr);
    };

    public func neuronAccountId(controller : Principal, nonce : Nat64) : AId.AccountIdentifier {
        let subaccount = neuronSubaccount(controller, nonce);
        return AId.fromPrincipal(controller, ?subaccount);
    };

    public func randomNat64() : async Nat64 {
        return Nat64.fromNat(Random.rangeFrom(64, await Random.blob()));
    };
}

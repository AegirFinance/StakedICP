import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import NNS "./NNS";
import Binary "./Binary";
import SHA256 "./SHA256";

module {
    public func neuronSubaccount(controller : Principal, nonce : Nat64) : NNS.Subaccount {
       var arr : [Nat8] = [
           0x0c, 0x6e, 0x65, 0x75,
           0x72, 0x6f, 0x6e, 0x2d,
           0x73, 0x74, 0x61, 0x6b,
           0x65
       ];
       
       arr := Array.append<Nat8>(arr, Blob.toArray(Principal.toBlob(controller)));
       arr := Array.append<Nat8>(arr, Binary.BigEndian.fromNat64(nonce));

       return Blob.fromArray(SHA256.sum256(arr));
    };

    public func neuronAccountId(governance : Principal, controller : Principal, nonce : Nat64) : NNS.AccountIdentifier {
        let subaccount = neuronSubaccount(controller, nonce);
        return NNS.accountIdFromPrincipal(governance, subaccount);
    };

    public func randomNat64() : async Nat64 {
        return Nat64.fromNat(Random.rangeFrom(64, await Random.blob()));
    };
}

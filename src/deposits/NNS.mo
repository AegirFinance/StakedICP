import Array     "mo:base/Array";
import Blob      "mo:base/Blob";
import Buffer    "mo:base/Buffer";
import Nat32     "mo:base/Nat32";
import Nat8      "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result    "mo:base/Result";
import Text      "mo:base/Text";
import CRC32     "./CRC32";
import Hex       "./Hex";
import SHA224    "./SHA224";

module {
  // 32-byte array.
  public type AccountIdentifier = Blob;
  // 32-byte array.
  public type Subaccount = Blob;

  // Checks whether two account identifiers are equal.
  public func accountIdEqual(a : AccountIdentifier, b : AccountIdentifier) : Bool {
      a == b;
  };

  // Hex string of length 64. The first 8 characters are the CRC-32 encoded
  // hash of the following 56 characters of hex.
  public func accountIdToText(accountId : AccountIdentifier) : Text {
      Hex.encode(Blob.toArray(accountId));
  };

  // Decodes the given hex encoded account identifier.
  // NOTE: does not validate if the hash/account identifier.
  public func accountIdFromText(accountId : Text) : Result.Result<AccountIdentifier, Text> {
      switch (Hex.decode(accountId)) {
          case (#err(e)) #err(e);
          case (#ok(bs)) #ok(Blob.fromArray(bs));
      };
  };

  func beBytes(n: Nat32) : [Nat8] {
    func byte(n: Nat32) : Nat8 {
      Nat8.fromNat(Nat32.toNat(n & 0xff))
    };
    [byte(n >> 24), byte(n >> 16), byte(n >> 8), byte(n)]
  };

  public func principalToSubaccount(principal: Principal) : Blob {
      let idHash = SHA224.Digest();
      idHash.write(Blob.toArray(Principal.toBlob(principal)));
      let hashSum = idHash.sum();
      let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
      let buf = Buffer.Buffer<Nat8>(32);
      let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

      return blob;
  };

  public func defaultSubaccount() : Subaccount {
    Blob.fromArrayMut(Array.init(32, 0 : Nat8))
  };

  public func accountIdFromPrincipal(principal: Principal, subaccount: Subaccount) : AccountIdentifier {
    let hash = SHA224.Digest();
    hash.write([0x0A]);
    hash.write(Blob.toArray(Text.encodeUtf8("account-id")));
    hash.write(Blob.toArray(Principal.toBlob(principal)));
    hash.write(Blob.toArray(subaccount));
    let hashSum = hash.sum();
    let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
    Blob.fromArray(Array.append(crc32Bytes, hashSum))
  };

  public func validateAccountIdentifier(accountIdentifier : AccountIdentifier) : Bool {
    if (accountIdentifier.size() != 32) {
      return false;
    };
    let a = Blob.toArray(accountIdentifier);
    let accIdPart    = Array.tabulate(28, func(i: Nat): Nat8 { a[i + 4] });
    let checksumPart = Array.tabulate(4,  func(i: Nat): Nat8 { a[i] });
    let crc32 = CRC32.ofArray(accIdPart);
    Array.equal(beBytes(crc32), checksumPart, Nat8.equal)
  };
}
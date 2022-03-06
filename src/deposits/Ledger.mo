module {
  public type AccountBalanceArgs = { account : AccountIdentifier };
  public type AccountIdentifier = [Nat8];
  public type BlockIndex = Nat64;
  public type Memo = Nat64;
  public type SubAccount = [Nat8];
  public type TimeStamp = { timestamp_nanos : Nat64 };
  public type Tokens = { e8s : Nat64 };
  public type TransferArgs = {
    to : AccountIdentifier;
    fee : Tokens;
    memo : Memo;
    from_subaccount : ?SubAccount;
    created_at_time : ?TimeStamp;
    amount : Tokens;
  };
  public type TransferError = {
    #TxTooOld : { allowed_window_nanos : Nat64 };
    #BadFee : { expected_fee : Tokens };
    #TxDuplicate : { duplicate_of : BlockIndex };
    #TxCreatedInFuture;
    #InsufficientFunds : { balance : Tokens };
  };
  public type TransferFee = { transfer_fee : Tokens };
  public type TransferFeeArg = {};
  public type TransferResult = { #Ok : BlockIndex; #Err : TransferError };
  public type Self = actor {
    account_balance : shared query AccountBalanceArgs -> async Tokens;
    decimals : shared query () -> async { decimals : Nat32 };
    name : shared query () -> async { name : Text };
    symbol : shared query () -> async { symbol : Text };
    transfer : shared TransferArgs -> async TransferResult;
    transfer_fee : shared query TransferFeeArg -> async TransferFee;
  }
}

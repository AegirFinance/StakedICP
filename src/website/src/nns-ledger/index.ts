export { idlFactory } from "./ledger.idl";

export const canisterId: string = process.env.NNS_LEDGER_CANISTER_ID ?? "";
if (!canisterId) {
  throw new Error("NNS_LEDGER_CANISTER_ID not set");
}

export { idlFactory } from "../../../declarations/nns-ledger/nns-ledger.did.js";

export const canisterId: string = process.env.NNS_LEDGER_CANISTER_ID ?? "";
if (!canisterId) {
  throw new Error("NNS_LEDGER_CANISTER_ID not set");
}

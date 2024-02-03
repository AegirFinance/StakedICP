export { idlFactory } from "../../../declarations/nns-ledger/nns-ledger.did.js";

export const canisterId: string = process.env.CANISTER_ID_NNS_LEDGER ?? "";
if (!canisterId) {
  throw new Error("CANISTER_ID_NNS_LEDGER not set");
}

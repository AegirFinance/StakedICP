export { idlFactory } from "../../../declarations/deposits/deposits.did.js";

export const canisterId: string = process.env.CANISTER_ID_DEPOSITS ?? "";
if (!canisterId) {
  throw new Error("CANISTER_ID_DEPOSITS not set");
}

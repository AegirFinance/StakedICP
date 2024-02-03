export { idlFactory } from "../../../declarations/token/token.did.js";

export const canisterId: string = process.env.CANISTER_ID_TOKEN ?? "";
if (!canisterId) {
  throw new Error("CANISTER_ID_TOKEN not set");
}

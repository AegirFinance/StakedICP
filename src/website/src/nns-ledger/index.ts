// Imports and re-exports candid interface
export { idlFactory } from "./ledger.idl";

// CANISTER_ID is replaced by webpack based on node environment
export const canisterId = process.env.NNS_LEDGER_CANISTER_ID;

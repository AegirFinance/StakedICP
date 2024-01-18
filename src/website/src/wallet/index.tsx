// import React from "react";
export * from "./components";
// export * from "./connectors";
// export * from "./hooks";
// export * from "./context";

import { createClient } from "@connect2ic/core";
import { InfinityWallet } from "@connect2ic/core/providers/infinity-wallet";
import { PlugWallet } from "@connect2ic/core/providers/plug-wallet";
import { Connect2ICProvider } from "@connect2ic/react";
import "@connect2ic/core/style.css";
import type { IDL } from "@dfinity/candid";

// Import our canisters
import * as deposits from "../../../declarations/deposits";
import * as token from "../../../declarations/token";
import * as nnsLedger from "../nns-ledger";
// How the connect2ic docs say to do it, but... I doubt it actually works.
// import * as deposits from "../../../../.dfx/local/canisters/deposits";
// import * as token from "../../../../.dfx/local/canisters/token";
// import * as nnsLedger from "../../../../.dfx/local/canisters/token";

export {
  ConnectDialog,
  useConnect,
  useDialog,
  useWallet,
  useProviders,
  useTransfer
} from "@connect2ic/react";
export { useBalance, useCanister } from "./hooks";

interface CanisterDefinition {
  canisterId: string;
  idlFactory: IDL.InterfaceFactory;
}

const canisters: Record<string, CanisterDefinition> = {
  deposits: {...deposits, canisterId: deposits.canisterId ?? ""},
  token: {...token, canisterId: token.canisterId ?? ""},
  nnsLedger
};

const client = createClient({
  canisters,
  globalProviderConfig: {
    // Determines whether root key is fetched
    // Should be enabled while developing locally & disabled in production
    dev: process.env.NODE_ENV === "development",
    // The host used for canisters
    host: process.env.NETWORK || window.location.origin,
    // Certain providers require specifying an app name
    appName: "StakedICP",
    // Certain providers require specifying which canisters are whitelisted
    // Array<string>
    whitelist: Object.values(canisters).map(c => c.canisterId).filter(x => !!x),
    // Certain providers allow you to specify a canisterId for the Ledger canister
    // For example when running it locally
    //
    // ledgerCanisterId: nnsLedger.canisterId,
    //
    // Certain providers allow you to specify a host for the Ledger canister
    // For example when running it locally
    ledgerHost: process.env.NETWORK || window.location.origin,
  },
  providers: [
    new InfinityWallet(),
    new PlugWallet()
  ]
});

export function Provider({ children }: { children: React.ReactNode }) {
  return <Connect2ICProvider client={client} children={children} />;
}

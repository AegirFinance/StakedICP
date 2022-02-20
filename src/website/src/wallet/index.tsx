import React from "react";
export * from "./components";
export * from "./connectors";
export * from "./hooks";
export * from "./context";

// function _useWalletHook(initial?: Wallet | null): WalletContextType {
//   const plug = (window as any).ic?.plug;
//   if (!plug) {
//     // TODO: Better handling here.
//     throw new Error("Please install plug wallet");
//   }

//   const [wallet, setWallet] = React.useState<Wallet|null>(initial);

//   const result: WalletContextType = {
//     async connect() {
//       // const connected = await plug.isConnected();
//       // if (!connected) {
//       //   return;
//       // }
//       // Make the request
//       const options = {
//         whitelist: [
//           process.env.DEPOSITS_CANISTER_ID,
//           process.env.TOKEN_CANISTER_ID,
//         ],
//         host: process.env.NETWORK,
//       };
//       const result = await plug.requestConnect(options);
//       const newIdentity = result ? await plug.agent.getPrincipal() : null
//       setWallet(newIdentity);
//       return newIdentity;
//     },
//     async disconnect() {
//       // TODO: This seems to hang
//       await plug.disconnect();
//       setWallet(null);
//     },
//     async getContract<T>(options: any) {
//       const actor = await plug.createActor(options);
//       if (!actor) {
//         throw new Error("Failed to initialize token client");
//       }
//       return actor as T;
//     },
//     async requestTransfer(options) {
//       return await plug.requestTransfer(options);
//     },
//     wallet,
//   };
//   result.connect = result.connect.bind(result);
//   result.disconnect = result.disconnect.bind(result);
//   result.getContract = result.getContract.bind(result);
//   result.requestTransfer = result.requestTransfer.bind(result);
//   return result;
// }

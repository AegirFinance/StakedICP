import { Plug } from "plug";
import { BitfinityWallet } from "bitfinity";

declare global {
  interface Window {
    ic?: null | {
      plug?: null | Plug
      infinityWallet?: null | BitfinityWallet
    }
  }
}

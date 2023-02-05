import { ActorSubclass } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import * as ledger from '../../../../declarations/ledger';
import { _SERVICE as Ledger } from "../../../../declarations/ledger/ledger.did.d.js";
import { ConnectorOptions, Data } from "./index";
import { Balance, RequestTransferParams } from "plug";
import { BitfinityWallet, CreateActor } from "bitfinity";

export interface BitfinityConnectorOptions extends ConnectorOptions {
    whitelist?: Array<string>;
    host?: string;
    dev?: boolean;
}

// TODO: Extend EventEmitter
// TODO: This needs to track the selected wallet.
export class BitfinityConnector {
  readonly name = "Bitfinity";
  readonly ready = typeof window !== 'undefined' && !!window.ic?.infinityWallet;
  private infinityWallet: BitfinityWallet | undefined;
  private options: BitfinityConnectorOptions;

  constructor(options: BitfinityConnectorOptions) {
    if (window.ic?.infinityWallet) {
      this.infinityWallet = window.ic?.infinityWallet;
    }
    this.options = options;
  }

  isSupported(): boolean {
    return !!this.infinityWallet;
  }

  async connect(): Promise<Data|null> {
    if(!this.infinityWallet){
      window.open('https://wallet.infinityswap.one/','_blank');
      return null;
    }

    const connected = await this.isAuthorized();
    if (!connected) {
      await this.infinityWallet.requestConnect(this.options);
    }
    const account = (await this.getPrincipal()).toString();
    return { account };
  }

  async disconnect(): Promise<void> {
    await this.infinityWallet?.disconnect();
  }

  async getAccountId(): Promise<string> {
    if (!this.infinityWallet) {
      throw new Error("BitfinityWallet wallet not found");
    }
    return await this.infinityWallet.getAccountID();
  }

  async isAuthorized(): Promise<boolean> {
    return await this.infinityWallet?.isConnected() || false;
  }

  async getBalances(): Promise<Balance[]> {
    const icp = await this.getICPLedger();
    const balance = await icp.account_balance({
         account: [...Buffer.from(await this.getAccountId(), 'hex')]
    });
    return [
        {
            amount: Number(balance.e8s) / 1e8,
            canisterId: ledger.canisterId ?? null,
            image: null,
            name: "ICP",
            symbol: "ICP",
            value: Number(balance.e8s),
        }
    ];
  }

  async createActor<T>(options: CreateActor<T>): Promise<ActorSubclass<T>> {
    if (!this.infinityWallet) {
      throw new Error("BitfinityWallet not found");
    }
    return await this.infinityWallet.createActor(options)
  }

  async getPrincipal(): Promise<Principal> {
    if (!this.infinityWallet) {
      throw new Error("BitfinityWallet wallet not found");
    }
    return this.infinityWallet.getPrincipal();
  }

  async transfer(params: RequestTransferParams): Promise<{ height: bigint }> {
    const icp = await this.getICPLedger();
    // TODO: Use all the request transfer params here
    const result = await icp.transfer({
        to: [...Buffer.from(params.to, 'hex')],
        fee: { e8s: BigInt(10000) },
        amount: { e8s: BigInt(params.amount) },
        memo: BigInt(0),
        from_subaccount: [], // For now, using default subaccount to handle ICP
        created_at_time: [],
    });
    if ('Err' in result) {
      // TODO: Better error message here
      throw new Error("Transfer failed")
    }
    return { height: result.Ok };
  }

  async getICPLedger(): Promise<ActorSubclass<Ledger>> {
      if (!ledger.canisterId) {
        // TODO: Handle missing canisterId better.
        throw new Error("Ledger canister id missing");
      }
      return await this.createActor({
          canisterId: ledger.canisterId,
          interfaceFactory: ledger.idlFactory,
          host: this.options.host,
      });
  }
}

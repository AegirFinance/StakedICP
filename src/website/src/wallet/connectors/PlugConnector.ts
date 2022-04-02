import { ActorSubclass } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { ConnectorOptions, Data } from "./index";
import type { Balance, CreateActor, Plug, RequestTransferParams } from "plug";

export interface PlugConnectorOptions extends ConnectorOptions {}

// TODO: Extend EventEmitter
// TODO: This needs to track the selected wallet in plug.
export class PlugConnector {
  readonly name = "Plug";
  readonly ready = typeof window !== 'undefined' && !!window.ic?.plug;
  private plug: Plug | undefined;
  private options: PlugConnectorOptions;

  constructor(options: PlugConnectorOptions) {
    if (window.ic?.plug) {
      this.plug = window.ic?.plug;
    }
    this.options = options;
  }

  isSupported(): boolean {
    return !!this.plug;
  }

  async connect(): Promise<Data|null> {
    if(!this.plug){
      window.open('https://plugwallet.ooo/','_blank');
      return null;
    }

    const connected = await this.isAuthorized();
    if (!connected) {
      await this.plug.requestConnect(this.options);
    }
    if (connected && !this.plug.agent) {
      await this.plug.createAgent(this.options);
    }
    const account = (await this.getPrincipal()).toString();
    return { account };
  }

  async disconnect(): Promise<void> {
    await this.plug?.disconnect();
  }

  async getAccountId(): Promise<string> {
    // TODO: Turn this into an account id
    return (await this.getPrincipal()).toString();
  }

  async isAuthorized(): Promise<boolean> {
    return await this.plug?.isConnected() || false;
  }

  async getBalances(): Promise<Balance[]> {
    // TODO: How do we need to query this to get the currently selected wallet number?
    return await this.plug?.requestBalance() || [];
  }

  async createActor<T>(options: CreateActor<T>): Promise<ActorSubclass<T>> {
    if (!this.plug) {
      throw new Error("Plug wallet not found");
    }
    return await this.plug.createActor(options)
  }

  async getPrincipal(): Promise<Principal> {
    if (!this.plug) {
      throw new Error("Plug wallet not found");
    }
    return this.plug.getPrincipal();
  }

  async transfer(params: RequestTransferParams): Promise<{ height: bigint }> {
    if (!this.plug) {
      throw new Error("Plug wallet not found");
    }
    return await this.plug.requestTransfer(params);
  }
}

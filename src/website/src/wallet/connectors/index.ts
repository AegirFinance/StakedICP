import { ActorSubclass } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
export * from "./PlugConnector";
import type { Balance, CreateActor, RequestConnectParams, RequestTransferParams } from "plug";

export interface Connector {
  readonly name: string;
  readonly ready: boolean;
  isSupported(): boolean;
  connect(): Promise<Data|null>;
  disconnect(): Promise<void>;
  getAccountId(): Promise<string>;
  isAuthorized(): Promise<boolean>;
  getBalances(accountId?: string): Promise<Balance[]>;
  createActor<T>(options: CreateActor<T>): Promise<ActorSubclass<T>>;
  getPrincipal: () => Promise<Principal>;
  transfer(params: RequestTransferParams): Promise<bigint>
}

export type Data = {
  account?: string
};

export type ConnectorOptions = RequestConnectParams;

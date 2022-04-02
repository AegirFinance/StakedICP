import { Agent, HttpAgent, Actor, ActorSubclass } from "@dfinity/agent";
import { IDL } from "@dfinity/candid";
import { Principal } from "@dfinity/principal";

declare global {
  interface Window {
    ic?: null | {
      plug?: null | Plug
    }
  }
}

declare module "plug" {
  export interface Plug {
    isConnected(): Promise<boolean>;
    disconnect(): Promise<void>;
    batchTransactions(transactions: Transaction[]): Promise<boolean>;
    requestBalance(accountId?: number | null): Promise<Balance[]>;
    requestTransfer(params: RequestTransferParams): Promise<bigint>;
    requestConnect(params: RequestConnectParams): Promise<any>;
    createActor<T>({
      canisterId,
      interfaceFactory,
    }: CreateActor<T>): Promise<ActorSubclass<T>>;
    agent: Agent | null;
    createAgent(params: CreateAgentParams): Promise<boolean>;
    // requestBurnXTC(params: RequestBurnXTCParams): Promise<any>;
    versions: ProviderInterfaceVersions;
    getPrincipal: () => Promise<Principal>;
  }

  export interface TransactionPrevResponse {
    transactionIndex: number;
    response: any;
  }

  export interface Transaction<SuccessResponse = unknown[]> {
    idl: IDL.InterfaceFactory;
    canisterId: string;
    methodName: string;
    args: (responses?: TransactionPrevResponse[]) => any[] | any[];
    onSuccess: (res: SuccessResponse) => Promise<any>;
    onFail: (err: any, responses?: TransactionPrevResponse[]) => Promise<void>;
  }

  // The amount in e8s (ICPs)
  export interface RequestTransferParams {
    to: string;
    amount: number;
    opts?: {
      fee?: bigint;
      memo?: string;
      from_subaccount?: number;
      created_at_time?: TimeStamp;
    };
  }

  export interface Balance {
    amount: number;
    canisterId: null | string;
    image: null | string;
    name: string;
    symbol: string;
    value: null | number;
  }

  export interface CreateActor<T> {
    agent?: HttpAgent;
    actor?: ActorSubclass<ActorSubclass<T>>;
    canisterId: string;
    interfaceFactory: IDL.InterfaceFactory;
  }

  export interface CreateAgentParams {
    whitelist?: string[];
    host?: string;
  }

  export interface RequestConnectParams extends CreateAgentParams {
    timeout?: number;
  }

  export interface ProviderInterfaceVersions {
    provider: string;
    extension: string;
  }
}

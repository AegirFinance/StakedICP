import { Agent, HttpAgent, Actor, ActorSubclass } from "@dfinity/agent";
import { IDL } from "@dfinity/candid";
import { Principal } from "@dfinity/principal";

declare module "bitfinity" {
  export interface BitfinityWallet {
    isConnected(): Promise<boolean>;
    disconnect(): Promise<void>;
    batchTransactions(transactions: Transaction<any>[], options?: {host?: string}): Promise<boolean>;
    requestConnect(params: RequestConnectParams): Promise<any>;
    createActor<T>({
      canisterId,
      interfaceFactory,
      host,
    }: CreateActor<T>): Promise<ActorSubclass<T>>;
    getAccountID: () => Promise<string>;
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

  export interface CreateActor<T> {
    canisterId: string;
    interfaceFactory: IDL.InterfaceFactory;
    host?: string;
  }

  export interface RequestConnectParams extends CreateAgentParams {
    whitelist?: string[];
    timeout?: number;
  }
}

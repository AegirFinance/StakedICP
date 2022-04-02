import { Principal } from "@dfinity/principal";
import React from 'react';
import * as contract from "../../../../declarations/token";
import { Token } from "../../../../declarations/token/token.did.js";
import { useContext } from "../context";
import * as format from "../../format";
import { useAsyncEffect } from "../../hooks";
import { useCacheBuster } from "./useCacheBuster";

export type Config = {
  /** Address or ENS name */
  addressOrName?: string
  /** Units for formatting output */
  formatUnits?: number
  /** Disables fetching */
  // skip?: boolean
  /** ERC-20 address */
  token?: string
  /** Subscribe to changes */
  // watch?: boolean
}

type State = {
  balance?: {
    decimals: number
    formatted: string
    symbol: string
    value: bigint
  }
  error?: Error
  loading?: boolean
}

const initialState: State = {
  loading: false,
}

export function useBalance({
  addressOrName,
  formatUnits = 8,
  token = undefined,
}: Config = {}) {
  const { state: { connecting, connector, data } } = useContext();
  const cacheBuster = useCacheBuster();
  const [state, setState] = React.useState<State>(initialState);
  const principal = data?.account;

  const getBalance = React.useCallback(async (config?: {
    addressOrName?: string
    formatUnits?: Config['formatUnits']
    token?: Config['token']
  }) => {
      setState(initialState);
      try {
        const config_ = config ?? {
          addressOrName: addressOrName ?? principal,
          formatUnits,
          token,
        }
        if (!config_.addressOrName) throw new Error('address is required');

        const formatUnits_ = config_.formatUnits ?? 8;

        setState((x) => ({ ...x, error: undefined, loading: true }));
        if (!connector) {
          return;
        }

        let balance: State['balance'];

        if (config_.token) {
          const actor = await connector.createActor<Token>({
            canisterId: config_.token,
            interfaceFactory: contract.idlFactory,
          });

          const value = await actor.balanceOf(Principal.from(config_.addressOrName));
          const decimals = await actor.decimals();
          const symbol = await actor.symbol();
          balance = {
            decimals,
            formatted: format.units(value, formatUnits_),
            symbol,
            value,
          };
        } else {
          // const balances = await connector.getBalances(config_.addressOrName);
          const balances = await connector.getBalances();
          const b = balances.find(b => b.symbol === 'ICP' && b.canisterId === null);
          if (!b) throw new Error("ICP balance not found");
          const value = BigInt(b.amount * 1e8);
          balance = {
            decimals: 8,
            formatted: format.units(value, formatUnits_),
            symbol: 'ICP',
            value,
          };
        }
        setState((x) => ({ ...x, balance, loading: false }));
        return { data: balance, error: undefined };
      } catch (error_) {
        const error = error_ as Error;
        setState((x) => ({ ...x, error, loading: false }));
        return { data: undefined, error };
      }
    }, [addressOrName, principal, connector, formatUnits, token]);

   /* eslint-disable react-hooks/exhaustive-deps */
  // TODO: Poll this periodically to refresh, or watch for new blocks
  useAsyncEffect(async () => {
    let a = addressOrName ?? principal;
    if (!a) return;
    getBalance({ addressOrName: a, formatUnits, token });
  }, [addressOrName, principal, connector, token, cacheBuster]);
  /* eslint-enable react-hooks/exhaustive-deps */

   return [
    {
      data: state.balance,
      error: state.error,
      loading: state.loading,
    },
    getBalance,
  ] as const;
}

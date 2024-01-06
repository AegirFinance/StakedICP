import { Principal } from "@dfinity/principal";
import React from 'react';
import { Token } from "../../../../declarations/token/token.did.js";
import * as format from "../../format";
import { useAsyncEffect } from "../../hooks";
import { useWallet, useCanister } from "..";

export type Config = {
  /** Principal of the user to fetch balance for */
  principal?: string
  /** Units for formatting output */
  formatUnits?: number
}

type State = {
  balance?: {
    decimals: number
    formatted: string
    value: bigint
  }
  error?: Error
  loading?: boolean
}

const initialState: State = {
  loading: false,
}

export function useBalance(token: string, config?: Config) {
  const [wallet] = useWallet();
  const [state, setState] = React.useState<State>(initialState);
  const principal = config?.principal ?? wallet?.principal;
  const decimals = config?.formatUnits ?? 8;

  const [canister, { loading: canisterLoading, error: canisterError }] = useCanister<Token>(token);

  const refetch = React.useCallback(async () => {
      if (!principal) {
          setState({
              loading: false,
              balance: {
                decimals,
                formatted: format.units(BigInt(0), decimals),
                value: BigInt(0),
              }
          });
      }
      if (!token) return;
      if (!canister) return;
      if (canisterLoading) return;
      setState(initialState);
      try {
        setState((x) => ({ ...x, error: undefined, loading: true }));
        let balance: State['balance'];

        const value = await canister.icrc1_balance_of({ owner: Principal.from(principal), subaccount: [] });
        balance = {
          decimals,
          formatted: format.units(value, decimals),
          value,
        };
        setState((x) => ({ ...x, balance, loading: false }));
        return { data: balance, error: undefined };
      } catch (error_) {
        const error = error_ as Error;
        setState((x) => ({ ...x, error, loading: false }));
        return { data: undefined, error };
      }
    }, [principal, token, !!canister, canisterLoading, config?.formatUnits]);

   /* eslint-disable react-hooks/exhaustive-deps */
  // TODO: Poll this periodically to refresh, or watch for new blocks
  useAsyncEffect(async () => {
    refetch();
  }, [principal, token, !!canister, canisterLoading, config?.formatUnits, refetch]);
  /* eslint-enable react-hooks/exhaustive-deps */

   return [
     state.balance,
     {
       refetch,
       error: state.error ?? canisterError,
       loading: state.loading,
     }
  ] as const;
}

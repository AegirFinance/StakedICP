import React from 'react';
import { useContext } from '../context';

export function useAccount() {
  const { state: globalState, setState } = useContext();
  const principal = globalState.data?.account;

  const disconnect = React.useCallback(() => {
    setState((x) => {
      x.connector?.disconnect()
      return { cacheBuster: x.cacheBuster + 1 }
    })
  }, [setState]);

  return [
    {
      data: principal
        ? {
            principal,
            connector: globalState.connector,
          }
        : undefined,
      error: null,
      loading: false,
    },
    disconnect,
  ] as const;
}

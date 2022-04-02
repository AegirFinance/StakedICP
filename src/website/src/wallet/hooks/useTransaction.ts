import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import React from "react";
import { RequestTransferParams } from "plug";
import { useContext } from "../context";

type Config = {
  /** Object to use when creating transaction */
  request?: Omit<RequestTransferParams, 'amount'> & {
    amount: BigNumberish
  };
}

type State = {
  height?: bigint
  error?: Error
  loading?: boolean
}

const initialState: State = {
  loading: false,
}

export function useTransaction({ request }: Config = {}) {
  const { state: { connector } } = useContext();
  const [state, setState] = React.useState<State>(initialState);

  const sendTransaction = React.useCallback(
    async (config?: { request: Config['request'] }) => {
      try {
        const config_ = config ?? { request };
        if (!config_.request) throw new Error('request is required');
        if (!connector) throw new Error("Connector not found");

        setState(x => ({ ...x, loading: true }));
        const { height } = await connector.transfer({
          ...config_.request,
          amount: BigNumber.from(config_.request.amount).toNumber(),
        });
        setState(x => ({ ...x, loading: false, height }));
        return { data: height, error: undefined };
      } catch (error_) {
        let error: Error = <Error>error_;
        setState(x => ({ ...x, error, loading: false }));
        return { data: undefined, error };
      }
    },
    [connector, request],
  );

  return [
    {
      data: state.height,
      error: state.error,
      loading: state.loading,
    },
    sendTransaction,
  ] as const;
}

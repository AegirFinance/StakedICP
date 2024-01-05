import React from 'react';
import { Deposits } from '../../../declarations/deposits/deposits.did.d.js';
import { useCanister } from '../wallet';
import { useInterval } from './index';

export type ExchangeRate = {
    stIcp: bigint,
    totalIcp: bigint,
};

export function useExchangeRate(): ExchangeRate|null {
    const [rate, setRate] = React.useState<ExchangeRate|null>(null);
    const [contract, { loading }] = useCanister<Deposits>("deposits", { mode: "anonymous" });
    const request = React.useCallback(async () => {
      if (!contract || loading) return;
      try {
        const [stIcp, totalIcp] : [bigint, bigint] = await contract.exchangeRate();
        if (stIcp === BigInt(0) || totalIcp === BigInt(0)) {
            console.error("Error fetching exchange rate", {stIcp, totalIcp});
            return;
        }
        setRate({stIcp, totalIcp});
      } catch (err) {
        console.error("Error fetching exchange rate", err);
      }
    }, [setRate, loading]);
    useInterval(request, 30000);
    React.useEffect(() => {
        request();
    }, []);
    return rate;
}

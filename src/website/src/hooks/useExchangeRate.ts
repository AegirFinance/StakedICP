import React from 'react';
import * as deposits from '../../../declarations/deposits';
import { Deposits } from '../../../declarations/deposits/deposits.did.d.js';
import { getBackendActor }  from '../agent';
import { useInterval } from './index';

export type ExchangeRate = {
    stIcp: bigint,
    totalIcp: bigint,
};

export function useExchangeRate(): ExchangeRate|null {
    const [rate, setRate] = React.useState<ExchangeRate|null>(null);
    const request = React.useCallback(async () => {
      try {
        // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
        if (!deposits.canisterId) throw new Error("Canister not deployed");
        const contract = await getBackendActor<Deposits>({canisterId: deposits.canisterId, interfaceFactory: deposits.idlFactory});
        const [stIcp, totalIcp] : [bigint, bigint] = await contract.exchangeRate();
        if (stIcp === BigInt(0) || totalIcp === BigInt(0)) {
            console.error("Error fetching exchange rate", {stIcp, totalIcp});
            return;
        }
        setRate({stIcp, totalIcp});
      } catch (err) {
        console.error("Error fetching exchange rate", err);
      }
    }, [setRate]);
    useInterval(request, 30000);
    React.useEffect(() => {
        request();
    }, []);
    return rate;
}

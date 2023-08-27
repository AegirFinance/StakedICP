import axios from 'axios';
import React from 'react';
import {
    Flex,
} from '../index';
import * as format from "../../format";
import { useInterval } from "../../hooks";

export function Price({amount}: {amount: bigint}) {
    const price = BigInt(Math.floor((usePrice() ?? 0) * 100));
    const total = price && amount && (amount * price)/BigInt(100_000_000);
    return (
        <Flex css={{ margin: '$1', flexDirection: "row", justifyContent: "flex-end", fontSize: '$1', fontWeight: 'light', color: '$slate11' }}>
            {total ? `($${format.units(total, 2, true)} USD)` : "(... USD)"}
        </Flex>
    );
}

function usePrice() {
    const [price, setPrice] = React.useState<undefined | number>(undefined);
    const request = React.useCallback(async () => {
      try {
        let response = await axios.get<{usd: number}>('https://stakedicp.com/api/price?api=true');
        setPrice(response.data.usd);
      } catch (err) {
        console.error("Error fetching ICP price", err);
      }
    }, [setPrice]);
    useInterval(request, 30000);
    React.useEffect(() => {
        request();
    }, []);
    return price;
}

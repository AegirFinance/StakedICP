import axios from 'axios';
import React from 'react';
import {
    Flex,
} from '../index';
import { useInterval } from "../../hooks";

export function Price({amount}: {amount: number}) {
    const price = fetchPrice();
    return (
        <Flex css={{ margin: '$1', flexDirection: "row", justifyContent: "flex-end", fontSize: '$1', fontWeight: 'light', color: '$slate11' }}>
            {price && amount ? `($${(price * amount).toFixed(2)} USD)` : "(... USD)"}
        </Flex>
    );
}

function fetchPrice() {
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

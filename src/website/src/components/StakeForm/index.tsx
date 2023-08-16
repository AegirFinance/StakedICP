import React from 'react';
import * as deposits from '../../../../declarations/deposits';
import { Deposits } from "../../../../declarations/deposits/deposits.did.d.js";
import { getBackendActor }  from '../../agent';
import { styled } from '../../stitches.config';
import { useInterval } from "../../hooks";
import { Flex } from '../index';
import { StakePanel } from "./StakePanel";
import { UnstakePanel } from "./UnstakePanel";

type Panels = 'stake' | 'delayed-unstake' | 'fast-unstake';

export function StakeForm() {
    const [active, setActive] = React.useState<Panels>('stake');

    const exchangeRate = useExchangeRate();

    return (
        <Flex css={{ flexDirection: "column", justifyContent: "stretch" }}>
            <Flex css={{ flexDirection: "row", justifyContent: "center" }}>
                <Nav>
                    <Item title="Stake" active={active === 'stake'} onClick={() => setActive('stake')}>Stake</Item>
                    <Item title="Delayed Unstake" active={active === 'delayed-unstake'} onClick={() => setActive('delayed-unstake')}>Delayed Unstake</Item>
                    <Item title="Fast Unstake (Coming Soon)" active={false} disabled={true}>Fast Unstake (Coming Soon)</Item>
                </Nav>
            </Flex>
            {active === 'stake' ? <StakePanel rate={exchangeRate} /> : <UnstakePanel rate={exchangeRate} />}
            <Attribution>Data from CoinGecko</Attribution>
        </Flex>
    );
}

const Nav = styled('nav', {
    margin: '$2 0',
    display: "flex",
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "baseline",
    background: '$slate1',
    padding: '$1',
    borderRadius: '$1',
    boxShadow: '$large',
});

const Item = styled('a', {
    fontWeight: 'bold',
    textDecoration: 'none',
    borderRadius: '0',
    padding: '$2 $3',
    '&:first-child': {
        borderRadius: '$1 0 0 $1',
    },
    '&:last-child': {
        borderRadius: '0 $1 $1 0',
    },
    '&:hover': {
        background: '$slate4',
        cursor: 'pointer',
    },
    variants: {
        active: {
            true: {
                background: '$slate5',
            },
        },
        disabled: {
            true: {
                color: '$slate9',
                '&:hover': {
                    cursor: 'not-allowed',
                    background: 'transparent',
                },
            },
        },
    },
});

const Attribution = styled('div', {
    fontWeight: 'light',
    fontSize: '$1',
    margin: '$2',
    display: "flex",
    flexDirection: "row",
    justifyContent: "flex-end",
    alignItems: "baseline",
});

export type ExchangeRate = {
    stIcp: bigint,
    totalIcp: bigint,
};

function useExchangeRate(): ExchangeRate|undefined {
    const [rate, setRate] = React.useState<undefined | ExchangeRate>(undefined);
    const request = React.useCallback(async () => {
      try {
        // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
        if (!deposits.canisterId) throw new Error("Canister not deployed");
        const contract = await getBackendActor<Deposits>({canisterId: deposits.canisterId, interfaceFactory: deposits.idlFactory});
        const [stIcp, totalIcp] : [bigint, bigint] = await contract.exchangeRate();
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

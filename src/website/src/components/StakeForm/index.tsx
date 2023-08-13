import React from 'react';
import {
    Flex,
} from '../index';
import { styled } from '../../stitches.config';
import { StakePanel } from "./StakePanel";
import { UnstakePanel } from "./UnstakePanel";

type Panels = 'stake' | 'unstake';

export function StakeForm() {
    const [active, setActive] = React.useState<Panels>('stake');
    return (
        <>
            <Flex css={{ flexDirection: "row", justifyContent: "center" }}>
                <Nav>
                    <Item title="Stake" active={active === 'stake'} onClick={() => setActive('stake')}>Stake</Item>
                    <Item title="Unstake" active={active === 'unstake'} onClick={() => setActive('unstake')}>Unstake</Item>
                </Nav>
            </Flex>
            {active === 'stake' ? <StakePanel /> : <UnstakePanel />}
            <Attribution>Data from CoinGecko</Attribution>
        </>
    );
}

const Nav = styled('nav', {
    margin: '$2',
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
    borderRadius: '$1',
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

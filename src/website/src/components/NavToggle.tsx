import React from "react";
import { Link } from "react-router-dom";
import { styled } from '../stitches.config';

export function NavToggle({active}: {active: 'stake'|'unstake'}) {
    return (
        <Nav>
            <Item to="/" title="Stake" active={active === 'stake'}>Stake</Item>
            <Item to="/unstake" title="Unstake" active={active === 'unstake'}>Unstake</Item>
        </Nav>
    );
}


const Nav = styled('nav', {
    margin: '$2',
    display: "flex",
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "baseline",
});

const Item = styled(Link, {
    fontWeight: 'bold',
    textDecoration: 'none',
    background: '$slate3',
    padding: '$2 $3',
    '&:first-child': {
        borderRadius: '$1 0 0 $1',
    },
    '&:last-child': {
        borderRadius: '0 $1 $1 0',
    },
    '&:hover': {
        background: '$slate4',
    },
    variants: {
        active: {
            true: {
                background: '$slate5',
            },
        },
    },
});


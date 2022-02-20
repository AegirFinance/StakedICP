import React from 'react';
import { styled } from '../stitches.config';

// TODO: do some media queries here
const Wrapper = styled('header', {
  display: "flex",
  flexDirection: "row",
  justifyContent: "flex-start",
  padding: '$2 $4',
  marginBottom: '$2',
  width: '100%',
  backgroundColor: '$slate12',
  color: '$slate1',
});

const Title = styled('b', {
  color: '$red9',
  marginRight: '$1',
});

export function TestnetBanner() {
  return (
    <Wrapper>
      <Title>Warning:</Title> Testnet mode. Balances will be periodically reset. ICP may be lost! Use at your own risk.
    </Wrapper>
  );
}

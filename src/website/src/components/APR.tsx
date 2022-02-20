import React from 'react';
import { idlFactory, canisterId } from '../../../declarations/deposits';
import { Deposits } from "../../../declarations/deposits/deposits.did.d.js";
import { getBackendActor }  from '../agent';
import * as format from "../format";
import { useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { HelpDialog } from './HelpDialog';

export function APR() {
  const [apr, setAPR] = React.useState<bigint|null>(null);

  useAsyncEffect(async () => {
    // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
    if (!canisterId) throw new Error("Canister not deployed");
    const contract = await getBackendActor<Deposits>({canisterId, interfaceFactory: idlFactory});

    const result = await contract.lastAprBips();
    setAPR(result);
  }, []);

  if (!apr) {
    return <Wrapper />;
  }

  return (
    <Wrapper>
      <Label>Stake ICP, earn up to</Label>
      <h1>{format.units(apr, 2)}% APR <HelpDialog aria-label="APR Details">
        <p>
          The rates shown on this page are only provided for your reference: The actual rates will fluctuate according to many different factors, including token prices, trading volume, liquidity, amount staked, and more.
        </p>
        <br />
        <p>
          Reward rates are adjusted roughly every 24 hours, based on the past 24 hours’ trading activity.
        </p>
        </HelpDialog></h1>
      
    </Wrapper>
  );
}

const Wrapper = styled('div', {
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  padding: "$1",
  borderRadius: '$1',
  minWidth: "300px",
  marginTop: '$4',
  marginBottom: '$4',
  minHeight: '58px',
});

const Label = styled('h2', {
  fontSize: '$3',
});

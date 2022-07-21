import { BigNumber } from "@ethersproject/bignumber";
import React from 'react';
import * as deposits from '../../../declarations/deposits';
import { Deposits } from "../../../declarations/deposits/deposits.did.d.js";
import * as token from '../../../declarations/token';
import { Token, TokenInfo } from "../../../declarations/token/token.did.d.js";
import { getBackendActor }  from '../agent';
import * as format from "../format";
import { useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { ActivityIndicator } from "./ActivityIndicator";
import { Flex } from "./Flex";
import { HelpDialog } from "./HelpDialog";

export function Statistics() {
  const [stats, setStats] = React.useState<TokenInfo|null>(null);
  const [apy, setAPY] = React.useState<bigint|null>(null);
  const [neurons, setNeurons] = React.useState<number|null>(null);

  useAsyncEffect(async () => {
    // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
    if (!token.canisterId) throw new Error("Canister not deployed");
    const contract = await getBackendActor<Token>({canisterId: token.canisterId, interfaceFactory: token.idlFactory});

    const tokenInfo = await contract.getTokenInfo();
    setStats(tokenInfo);
  }, []);

  useAsyncEffect(async () => {
    // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
    if (!deposits.canisterId) throw new Error("Canister not deployed");
    const contract = await getBackendActor<Deposits>({canisterId: deposits.canisterId, interfaceFactory: deposits.idlFactory});

    // TODO: Do this with bigint all the way through for more precision.
    const microbips : number = new Number(await contract.aprMicrobips()).valueOf();
    // apy = (((1+(microbips / 100_000_000))^365.25) - 1)
    const apy = Math.pow(1 + (microbips / 100_000_000), 365.25) - 1;
    // display it with two decimals, so 0.218 = 21.80%
    setAPY(BigNumber.from(Math.round(apy * 10_000)).toBigInt());
  }, []);

  useAsyncEffect(async () => {
    // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
    if (!deposits.canisterId) throw new Error("Canister not deployed");
    const contract = await getBackendActor<Deposits>({canisterId: deposits.canisterId, interfaceFactory: deposits.idlFactory});

    // TODO: Do this with bigint all the way through for more precision.
    const neurons = await contract.stakingNeurons();
    setNeurons(neurons.length);
  }, []);

  return (
    <Wrapper>
      <Item>
        <h5>Total ICP Staked</h5>
        <h2>
          {stats !== null
            ? `${formatSupply(stats.metadata.totalSupply)} ICP`
            : <ActivityIndicator />}
        </h2>
      </Item>
      <Item>
        <h5>Stakers</h5>
        <h2>
          {stats !== null
            ? `${stats.holderNumber || 0}`
            : <ActivityIndicator />}
        </h2>
      </Item>
      <Item>
        <h5>
          <span>APY</span>
          <HelpDialog aria-label="APY Details">
            <p>
              The rates shown on this page are only provided for your reference: The actual rates will fluctuate according to many different factors, including token prices, trading volume, liquidity, amount staked, and more. Rates are based on NNS voting rewards, which fluctuates with the number of proposals in a given week.
            </p>
            <br />
            <p>
              Reward rates are adjusted roughly every 24 hours, based on the past 7 days’ activity.
            </p>

            <p>
              Rewards are distributed daily. There can be up to 48 hours between
              when you deposit, and when you receive your first rewards.
            </p>
          </HelpDialog>
        </h5>
        <h2>
          {apy
            ? <>{format.units(apy, 2)}%</>
            : <ActivityIndicator />}
        </h2>
      </Item>
      <Item>
        <h5>Neurons</h5>
        <h2>
          {neurons || <ActivityIndicator />}
        </h2>
      </Item>
    </Wrapper>
  );
}

const Wrapper = styled('div', {
  display: 'grid',
  gridAutoColumns: 'minmax(0, 1fr)',
  gridAutoFlow: 'column',
  padding: "$4",
});

const Item = styled(Flex, {
  margin: '$4',
  padding: '$4',
  maxWidth: 300,
  backgroundColor: '$slate1',
  borderRadius: '$1',
  flexDirection: 'column',
  alignItems: 'stretch',
  whiteSpace: 'nowrap',
  boxShadow: '$medium',
  '& h5': {
    display: 'flex',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  '& h2': {
  },
});

function formatSupply(supply?: bigint): string {
  supply = supply || BigInt(0);
  supply = supply / BigInt(100_000_000);
  if (supply > 1_000_000_000) {
    return `${supply / BigInt(1_000_000_000)}b`;
  }
  if (supply > 1_000_000) {
    return `${supply / BigInt(1_000_000)}m`;
  }
  if (supply > 1_000) {
    return `${supply / BigInt(1_000)}k`;
  }
  return `${supply}`;
}

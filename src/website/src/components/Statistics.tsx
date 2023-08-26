import { BigNumber } from "@ethersproject/bignumber";
import React from 'react';
import * as deposits from '../../../declarations/deposits';
import { Deposits } from "../../../declarations/deposits/deposits.did.d.js";
import * as token from '../../../declarations/token';
import { Token, TokenInfo } from "../../../declarations/token/token.did.d.js";
import { getBackendActor }  from '../agent';
import * as format from "../format";
import { ExchangeRate, useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { ActivityIndicator } from "./ActivityIndicator";
import { Flex } from "./Flex";
import { HelpDialog } from "./HelpDialog";

export function Statistics({neurons, rate}: {neurons: string[]|null, rate: ExchangeRate|null}) {
  const [stats, setStats] = React.useState<TokenInfo|null>(null);
  const [apy, setAPY] = React.useState<bigint|null>(null);

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

  return (
    <Wrapper>
      <ItemRow>
        <Item>
          <h5>Total ICP Staked</h5>
          <h2>
            {rate?.totalIcp
              ? `${formatSupply(rate.totalIcp)} ICP`
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
      </ItemRow>
      <ItemRow>
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
          <h5>
            <span>Neurons</span>
            <HelpDialog aria-label="Neuron Details">
              <p>
                When you stake ICP, the protocol canisters deposit the ICP into
                a collection of neurons in the NNS to earn NNS voting rewards.
                The canisters manage and rebalanced the neurons to maintain the
                liquidity and yield profile of the protocol. The neurons have a
                range of staking delays, from 6 months, up to 8 years.
              </p>
              <br />
              <p>
                There are 16 neurons, because:
              </p>
              <p>
                6 months + 1 year + 1.5 years + ... + 8 years = 16 neurons
              </p>
            </HelpDialog>
          </h5>
          <h2>
            {neurons?.length ?? <ActivityIndicator />}
          </h2>
        </Item>
      </ItemRow>
    </Wrapper>
  );
}

const Wrapper = styled('div', {
  display: 'flex',
  flexDirection: 'row',
  justifyContent: 'center',
  flexWrap: 'wrap',
});

const ItemRow = styled('div', {
  display: 'flex',
  flexDirection: 'row',
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
    '& > * + *': {
        marginLeft: '$1',
    }
  },
  '& h2': {
  },
});

function formatSupply(supply?: bigint): string {
  supply = supply || BigInt(0);
  supply = supply / BigInt(100_000_000);
  if (supply > 1_000_000_000) {
    const supplyN = Math.floor(Number(supply) / 10_000_000) / 100;
    return `${supplyN.toFixed(2).replace(/\.00$/, '')}b`;
  }
  if (supply > 1_000_000) {
    const supplyN = Math.floor(Number(supply) / 10_000) / 100;
    return `${supplyN.toFixed(2).replace(/\.00$/, '')}m`;
  }
  if (supply > 1_000) {
    const supplyN = Math.floor(Number(supply) / 10) / 100;
    return `${supplyN.toFixed(2).replace(/\.00$/, '')}k`;
  }
  return `${supply}`;
}

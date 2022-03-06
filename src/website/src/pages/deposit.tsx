import * as Accordion from '@radix-ui/react-accordion';
import { ChevronDownIcon, GitHubLogoIcon, TwitterLogoIcon } from '@radix-ui/react-icons';
import React from 'react';
import { BrowserRouter } from "react-router-dom";
import * as deposits from "../../../declarations/deposits";
import * as token from "../../../declarations/token";
import { APR, DepositForm, Flex, Header, Layout, PreviewPassword, Statistics, TestnetBanner } from '../components';
import { globalCss, keyframes, styled } from '../stitches.config';
import { Provider as WalletProvider } from "../wallet";

export function Deposit() {
  return (
    <Layout>
      <Header />
      <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
        <APR />
        <Features />
      </Flex>
      <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
        <div>
          <DepositForm />
          <Subtitle>Statistics</Subtitle>
          <Statistics />
          <Subtitle>FAQ</Subtitle>
          <FAQ />
          <Links />
        </div>
      </Flex>
    </Layout>
  );
}

const Subtitle = styled('h2', {
  alignSelf: 'flex-start',
  marginTop: '$4',
  marginBottom: '$2',
});

function Features() {
  return (
    <Flex css={{flexDirection:"row", flexWrap: "wrap", alignItems:"space-around", padding: "$4", maxWidth: 1024}}>
      <Feature>
        <h2>Auto-Compounding</h2>
        <p>ICP is staked for 8 years, and interest accrues daily to maximize your returns. No more manual merge-maturity.</p>
      </Feature>
      <Feature>
        <h2>No Lock-in (Soon)</h2>
        <p>Sell your stICP for ICP at any time.</p>
      </Feature>
      <Feature>
        <h2>ICP Native</h2>
        <p>No bridging or swapping. All ICP stays on-chain.</p>
      </Feature>
    </Flex>
  );
}

const Feature = styled(Flex, {
  flexDirection: "column",
  margin: '$4',
  maxWidth: 300,
});

function FAQ() {
  return (
    <AccordionRoot type="multiple">
      <AccordionItem value="what-is-stakedicp">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What is StakedICP?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
            StakedICP is a liquid staking solution for ICP. StakedICP lets users stake their ICP - without locking assets or maintaining infrastructure - whilst participating in on-chain activities, e.g. lending.
          </p>

          <p>
            Our goal is to solve the problems associated with initial ICP staking - illiquidity, immovability and accessibility - making staked ICP liquid, automating neuron compounding, and allowing usage in decentralised finance.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="how-does-stakedicp-work">
        <AccordionHeader>
          <AccordionTrigger>
            <span>How does StakedICP work?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          When staking with StakedICP, users receive stICP tokens on a 1:1 basis representing their staked ICP. stICP balances can be used like regular ICP to earn yields and lending rewards, and are updated on a daily basis to reflect your ICP staking rewards.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="what-is-liquid-staking">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What is liquid staking?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          Liquid staking protocols allow users to earn staking rewards without locking assets or maintaining staking infrastructure. Users can deposit tokens and receive tradable liquid tokens in return.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="what-is-sticp">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What is stICP?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          stICP is a token that represents staked ICP in the StakedICP neuron, combining the value of initial deposit + staking rewards. stICP tokens are minted upon deposit and burned when redeemed. stICP token balances are pegged 1:1 to the ICP that are staked by StakedICP. stICP token’s balances are updated daily when staking rewards accrue.
          </p>

          <p>
          stETH tokens are a standard <a href="https://github.com/Psychedelic/DIP20">DIP20 token</a>, allowing you to earn ICP staking rewards while benefitting from e.g. yields across decentralised finance products.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="how-is-stakedicp-secure">
        <AccordionHeader>
          <AccordionTrigger>
            <span>How is StakedICP secure?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          Pending audit results, StakedICP will be open-source, and all code will be continuously reviewed.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="what-is-the-difference-between-self-staking-and-liquid-staking">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What is the difference between self staking and liquid staking?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          The Internet Computer is soon to be the biggest staking economy in the space. However, staking on NNS requires daily work to ensure the best compounding rewards.In addition to this, for the best rewards, tokens are locked up for years.
          </p>

          <p>
          Through the use of a liquid-staking service such as StakedICP, users can eliminate these inconveniences and benefit from secure staking backed by industry leaders.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="what-are-the-risks-of-staking-with-stakedicp">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What are the risks of staking with StakedICP?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          There exist a number of potential risks when staking ICP using liquid staking protocols.
            <ul>
              <li>
                <p>
                Smart contract security
                </p>
                <p>
                There is an inherent risk that StakedICP could contain a smart contract vulnerability or bug. The StakedICP code will be open-sourced, audited and covered by an extensive bug bounty program to minimise this risk.
                </p>
              </li>

              <li>
              Internet Computer - Technical risk
                <br />
                StakedICP is built atop experimental technology under active development, and there is no guarantee that the Internet Computer has been developed error-free. Any vulnerabilities inherent to the Internet Computer brings risk with it.
              </li>

              <li>
              Internet Computer - Adoption risk
                <br />
                The value of stICP is built around the staking rewards associated with the Dfinity Internet Computer. If the Internet Computer fails to reach required levels of adoption we could experience significant fluctuations in the value of ICP and stICP.
              </li>

              <li>
              StakedICP key management risk
                <br />
                ICP staked via StakedICP is locked securely in the StakedICP neuron to minimise custody risk. If neuron account keys are lost, or get hacked, we risk funds becoming locked.
              </li>

              <li>
              stICP price risk
                <br />
                Users risk an exchange price of stICP which is lower than inherent value due to withdrawal restrictions on StakedICP, making arbitrage and risk-free market-making impossible. StakedICP is driven to mitigate these risks and eliminate them entirely to the extent possible. Despite this, they may still exist and, as such, it is our duty to communicate them.
              </li>
            </ul>
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="what-fee-is-applied-by-stakedicp">
        <AccordionHeader>
          <AccordionTrigger>
            <span>What fee is applied by StakedICP? What is this used for?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          StakedICP applies a 10% fee on a user's staking rewards. This fee is used to ensure ongoing development and support, and grow the ecosystem.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="how-can-sticp-be-converted-to-icp">
        <AccordionHeader>
          <AccordionTrigger>
            <span>How can stICP be converted to ICP?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          To ensure maximum staking rewards, all ICP earned while staked, is automatically merged into the StakedICP neuron(s). While there's currently no way to withdraw ICP from staking, stICp holders may soon exchange their stICP to ICP on liquidity pools.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="can-sticp-holders-vote-on-nns-proposals?">
        <AccordionHeader>
          <AccordionTrigger>
            <span>Can stICP holders vote on NNS proposals?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <p>
          To prevent manipulation and vote-buying, stICP holders cannot directly vote on NNS proposals. All ICP held by StakedICP follows the <a href="https://www.ic.community/followee-neuron-for-icp-maximalist-network/">ICP Maximalist Network neuron</a> to maximize rewards.
          </p>
	  <p>
	  All held ICP is locked securely in the StakedICP neuron: <a href="https://dashboard.internetcomputer.org/neuron/16136654443876485299">16136654443876485299</a>.
	  </p>
        </AccordionContent>
      </AccordionItem>
    </AccordionRoot>
  );
}

const AccordionRoot = styled(Accordion.Root, {
  width: '400px',
  maxWidth: '100%',
});

const AccordionItem = styled(Accordion.Item, {
  backgroundColor: '$slate3',
  marginBottom: '$2',
  padding: '$2',
  borderRadius: '$1',
});

const AccordionHeader = styled(Accordion.Header, {
  all: 'unset',
  display: 'flex',
});

const AccordionTrigger = styled(Accordion.Trigger, {
  all: 'unset',
  flex: 1,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
});


const open = keyframes({
  from: { height: 0 },
  to: { height: 'var(--radix-accordion-content-height)' },
});

const close = keyframes({
  from: { height: 'var(--radix-accordion-content-height)' },
  to: { height: 0 },
});

const AccordionContent = styled(Accordion.Content, {
  maxWidth: '600px',
  padding: '$2 0',
  '&[data-state="open"]': { animation: `${open} 300ms ease-out` },
  '&[data-state="closed"]': { animation: `${close} 300ms ease-out` },
  '& > * + *': {
    marginTop: '$2',
  },
  'ul': {
    listStylePosition: 'outside',
    marginLeft: '1.6em',
  },
  'li': {
    marginTop: '$2',
  },
  'p': {
    display: 'block',
  }
});

const AccordionChevron = styled(ChevronDownIcon, {
  transition: 'transform 300ms',
  '[data-state=open] &': { transform: 'rotate(180deg)' },
});

function Links() {
  return (
    <Flex css={{flexDirection:"row", justifyContent: "center", alignItems:"center", padding: "$2", '& > *': {margin: '$2'}}}>
      <a href="https://github.com/AegirFinance" title="Github"><GitHubLogoIcon /></a>
      <a href="https://twitter.com/StakedICP" title="Twitter"><TwitterLogoIcon /></a>
    </Flex>
  );
}

import * as Accordion from '@radix-ui/react-accordion';
import { ChevronDownIcon, GitHubLogoIcon, TwitterLogoIcon } from '@radix-ui/react-icons';
import React from 'react';
import { Deposits } from "../../../declarations/deposits/deposits.did.d.js";
import { useCanister } from "../wallet";
import {
  ActivityIndicator,
  Code,
  Flex,
  Header,
  Layout,
  StakeForm,
  Statistics,
} from '../components';
import { useAsyncEffect, useExchangeRate } from "../hooks";
import { keyframes, styled } from '../stitches.config';

export function Stake() {
  const [neurons, setNeurons] = React.useState<string[]|null>(null);
  const rate = useExchangeRate();

  const [contract, { loading }] = useCanister<Deposits>("deposits", { mode: "anonymous" });
  useAsyncEffect(async () => {
    if (!contract || loading) return;
    // TODO: Do this with bigint all the way through for more precision.
    const neurons = await contract.stakingNeurons();
    setNeurons(neurons.map(n => `${n.id.id}`));
  }, [!!contract, loading]);

  return (
    <Wrapper>
      <Layout>
        <Header />
        <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
          <Statistics neurons={neurons} rate={rate} />
        </Flex>
        <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2", marginBottom: '$16'}}>
          <StakeForm rate={rate} />
        </Flex>
        <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2", backgroundColor: '$slate1', zIndex: 999, position: 'relative', marginBottom: '$8'}}>
          <Features />
        </Flex>
        <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
          <div>
            <Subtitle>FAQ</Subtitle>
            <FAQ neurons={neurons} />
            <Links />
          </div>
        </Flex>
      </Layout>
    </Wrapper>
  );
}

const Wrapper = styled('div', {
  background: "radial-gradient(circle farthest-corner at 20% 20%, rgba(18,165,148,.16), rgba(242,145,2,.07) 25%, rgba(166,103,10,0) 63%)",
});

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
        <p>ICP is staked for 8 years, and interest accrues daily to maximize your returns. You automatically receive the benefits of staking just by holding the stICP token.</p>
      </Feature>
      <Feature>
        <h2>No Lock-in</h2>
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

function FAQ({neurons}: {neurons: string[]|null}) {
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
          When staking with StakedICP, users receive stICP tokens representing their staked ICP and earned maturity. stICP balances can be used like regular ICP to earn yields and lending rewards, and represent your staked ICP, and earned staking rewards.
          </p>

          <p>
            <code>
              stICP:ICP ratio = (total stICP supply) / (total ICP staked + total NNS maturity earned)
            </code>
          </p>

          <p>
          Rewards are based on the underlying NNS voting rewards, so can fluctuate based on the number of proposals (among other factors).
          </p>

          <p>
          Since the NNS voting rewards will constantly accumulate, this means that stICP's value effectively always increases relative to ICP. The ICP/stICP exchange rate is updated approximately every 24 hours based on the NNS voting rewards earned by the staking neurons.
          </p>

          <p>
          To illustrate this point, here is a chart of stICP's value (relative to ICP) over time - as expected, it demonstrates slow but steady growth:
          </p>

          <p>
          <img src="/exchange-rate-example.png" style={{width: "100%"}} />
          </p>

          <p>
          Let's do a simple example as a demonstration.
          </p>

          <p>
          Say you stake at the very beginning when 1 ICP = 1 stICP. You deposit 10 ICP and receive 10 stICP back.
          </p>

          <p>
          After a few years, the balances in the protocol grow due to NNS voting rewards. Say 128 ICP had been staked with StakedICP and the sum of all neuron balances on the NNS was 160 ICP. Then 1 ICP would be worth (128/160) = 0.8 stICP; conversely, 1 stICP would be worth (160/128) = 1.25 ICP.
          </p>

          <p>
          At this point, you could unstake or trade your 10 stICP and receive 12.5 ICP in return.
          </p>

          <p>
          This means as long as you are holding stICP, you are staking with StakedICP! You do not need to get it from StakedICP directly. For example, you can purchase stICP on an exchange; as every stICP token is exactly the same, you will automatically receive the benefits of staking just by holding the token!
          </p>

          <p>
          In v1 of the protocol (released 2022), both the staking neurons and the canisters were controlled by the StakedICP team directly. This allowed us to ship faster and test the product.
          </p>

          <p>
          As of May 2023, the v2 of the protocol has launched. In v2, the staking neurons are no-longer directly controlled by the team, but are owned and controlled on-chain by the canisters themselves. The canisters, however are still managed by the StakedICP team. This allows the team to upgrade the code, adding features and continuing to build.
          </p>

          <p>
          Eventually, we would like for the protocol to be fully under community goverenance. Full DAO control is the goal.
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
          Liquid staking protocols allow users to earn staking rewards without locking assets or maintaining staking infrastructure. Users can stake tokens and receive tradable liquid tokens in return.
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
          stICP is a token that represents staked ICP in the StakedICP NNS neurons. The token combines the value of the initial stake + earned staking rewards. stICP tokens are minted upon stake and burned when redeemed. stICP token’s balances do not update, but the value of stICP increases relative to ICP.
          </p>

          <p>
          The stICP/ICP exchange rate is updated approximately every 24 hours based on the NNS voting rewards earned by the StakedICP neurons.
          </p>

          <p>
          stICP tokens are a standard <a href="https://github.com/dfinity/ICRC-1">ICRC-1 token</a>, allowing you to earn ICP staking rewards while benefitting from e.g. yields across decentralised finance products. They do not confer any voting or governance rights.
          </p>

          <p>
          To prevent abuse, the stICP transaction fee is set at 0.0001. The same as normal ICP.
          </p>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="add-stICP-to-bitfinity">
        <AccordionHeader>
          <AccordionTrigger>
            <span>How do I add stICP to my Bitfinity Wallet?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <ol>
            <li>Open your Bitfinity Wallet</li>
            <li>Click the blue "+" button in the bottom right of the token list</li>
            <li>Click "Add Token"</li>
            <li>Search for <Code>stICP</Code></li>
            <li>Select stICP from the list</li>
            <li>"stICP" should now appear in your token list, with your balance</li>
          </ol>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="add-stICP-to-plug">
        <AccordionHeader>
          <AccordionTrigger>
            <span>How do I add stICP to my Plug Wallet?</span>
            <AccordionChevron aria-hidden />
          </AccordionTrigger>
        </AccordionHeader>
        <AccordionContent>
          <ol>
            <li>Open plug</li>
            <li>Click the large blue plus icon to add a token</li>
            <li>Click "Custom", to add a custom token</li>
            <li>For "Token Canister ID", paste: <Code>qfr6e-biaaa-aaaak-qafuq-cai</Code></li>
            <li>For "Token Standard", select: <Code>ICRC1</Code></li>
            <li>Click "Continue"</li>
            <li>Click "Add"</li>
            <li>"Staked ICP" should now appear in your plug token list, with your balance</li>
          </ol>
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
          All code for StakedICP is reviewed before deployment, and on an ongoing basis.
          </p>

          <p>
          The system is designed to rely as little as possible on human intervention or trust. For example, the StakedICP canisters use the Internet Computer's Chain-key transactions to own and control the staking neurons. This ensures that the canisters are the only ones capable of controlling the staking neurons.
          </p>

          <p>
          Development is still ongoing, but we are coordinating with auditors to release audit results once the entire protocol is code-complete.
          </p>

          <p>
          For more information, see "What are the risks of staking with StakedICP?" below.
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
          The Internet Computer is soon to be the biggest staking economy in the space. However, staking on the NNS requires long token lock-ups with no liquidity. When your tokens are locked in the NNS there is no way to re-use them for DeFi, or get early-access to your rewards.
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
                Smart contract security
                <br />
                StakedICP's code has been reviewed internally and externally, but it hasn't yet undergone a formal audit. While we've taken steps to ensure its quality, it's important to acknowledge the potential for bugs. Our code review process helps identify issues, but it's impossible to guarantee a completely bug-free code. We're committed to transparency about this reality. Make sure to conduct your own due diligence and research before making any decisions. Always DYOR.
                <br />
                The canister and website source code is open-source <a href="https://github.com/AegirFinance/StakedICP">on Github</a>
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
                The StakedICP canisters use the Internet Computer's Chain-key transactions to own and control the staking neurons.
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
          If you go to "Unstake" above, you can begin withdrawing your stICP. This will burn the stICP, and begin unstaking the corresponding ICP from the NNS. There can be a delay to this process.
          </p>

          <p>
          Soon, stICP holders may exchange their stICP to ICP on liquidity pools, for faster conversion.
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
          To prevent manipulation and vote-buying, stICP holders cannot directly vote on NNS proposals. All ICP held by StakedICP follows the <a href="https://www.synapse.vote/">Synapse.Vote neuron</a> to maximize rewards.
          </p>
          <p>
          All held ICP is locked securely in the StakedICP neurons:
          </p>
          {neurons ? (
            <ul>
              {neurons.map(id =>
                <li key={id}>
                  <a href={`https://dashboard.internetcomputer.org/neuron/${id}`}>{id}</a>
                </li>
              )}
            </ul>
          ) : (
            <ActivityIndicator />
          )}
        </AccordionContent>
      </AccordionItem>
    </AccordionRoot>
  );
}

const AccordionRoot = styled(Accordion.Root, {
  width: '390px',
  maxWidth: '100%',
});

const AccordionItem = styled(Accordion.Item, {
  overflow: 'hidden',
  backgroundColor: '$slate1',
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
  overflow: 'hidden',
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
  'ol': {
    listStyleType: 'decimal',
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

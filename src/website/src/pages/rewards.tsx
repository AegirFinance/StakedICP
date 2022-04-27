import { ClipboardCopyIcon } from '@radix-ui/react-icons'
import React from 'react';
import * as deposits from "../../../declarations/deposits";
import { Deposits, ReferralStats } from "../../../declarations/deposits/deposits.did";
import { ActivityIndicator, Code, CopyOnClick, Flex, Header, HelpDialog, Layout } from '../components';
import * as format from "../format";
import { useAsyncEffect } from '../hooks';
import { styled } from '../stitches.config';
import { ConnectButton, useAccount, useCanister } from "../wallet";

export function Rewards() {
  const [stats, setStats] = React.useState<ReferralStats|null>(null);
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const depositsCanister = useCanister<Deposits>({
    // TODO: handle missing canister id better
    canisterId: deposits.canisterId ?? "",
    interfaceFactory: deposits.idlFactory,
  });

  useAsyncEffect(async () => {
      setStats(null);
      if (!principal || !depositsCanister) {
          return;
      }
      setStats(await depositsCanister.getReferralStats());
  }, [principal, !!depositsCanister, setStats]);

  const referralUrl = stats && `https://stakedicp.com/?r=${encodeURIComponent(stats.code)}`;

  
  return (
    <Wrapper>
      <Layout>
        <Header />
        <Hero>
            <Feature>
                <h2>Refer friends, earn 2.5% on their interest. For life.</h2>
            </Feature>
        </Hero>
        {principal ? (
            <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
                <Grid css={{width: '100%', maxWidth: 600}}>
                    <Key>Your Referral Link:</Key>
                    <Value>
                        <Code>{referralUrl || <ActivityIndicator />}</Code>
                    </Value>
                    <Side>
                        <CopyOnClick value={referralUrl || ""} disabled={!referralUrl}><ClipboardCopyIcon style={{padding: "0.25rem", marginTop: 3}} color={referralUrl ? "black" : "transparent" } /></CopyOnClick>
                    </Side>
                    <Explanation>
                        <p>
                            Use your referral link to recruit new users. Anyone
                            who makes their first deposit within 30 days of
                            clicking your link will become one of your referred
                            users. From then on, you earn 2.5% on any interest
                            they receive. Earnings are paid in stICP.
                        </p>
                    </Explanation>
                    <Key>Your Referred Users:</Key>
                    <Value>
                        <Code>{stats?.count !== undefined ? `${stats.count}` : <ActivityIndicator />}</Code>
                    </Value>
                    <Side aria-label="Earnings Info">
                        <HelpDialog>
                            <p>
                                You can't refer yourself, so signing up with
                                the same account will not be reflected here, or
                                in earnings.
                            </p>
                        </HelpDialog>
                    </Side>
                    <Key>Lifetime Referral Earnings:</Key>
                    <Value>
                        <Code>{stats?.earned !== undefined ? format.units(stats?.earned) : <ActivityIndicator css={{marginRight: "1ch", display: "inline-block"}} />} stICP</Code>
                    </Value>
                    <Side aria-label="Earnings Info">
                        <HelpDialog>
                            <p>
                                All earnings are immediately sent to your stICP
                                balance. This number is the total amount of
                                stICP you have earned by referring other users.
                            </p>
                        </HelpDialog>
                    </Side>
                </Grid>
            </Flex>
        ) : (
            <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>

                <ConnectButton />
                <p style={{marginTop: "0.5rem"}}>Connect your wallet to begin earning.</p>
            </Flex>
        )}
      </Layout>
    </Wrapper>
  );
}

const Wrapper = styled('div', {
});

const Hero = styled('div', {
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

const Label = styled('h1', {
  fontSize: '$3',
});

const Feature = styled(Flex, {
  flexDirection: "column",
  margin: '$2',
});

const Grid = styled('div', {
  display: 'grid',
  gridTemplateColumns: "min-content auto",
  gap: "$1 $2",
  justifyContent: 'stretch',
  alignItems: 'center',
});

const Key = styled('div', {
  whiteSpace: "nowrap",
  gridColumn: '1 / span 1',
});

const Value = styled(Flex, {
  gridColumn: '2 / span 1',

  alignSelf: 'stretch',
  width: '100%',
  flexDirection: 'row',
  flexWrap: "nowrap",
  justifyContent: 'flex-end',
});

const Side = styled('div', {
  gridColumn: '3 / span 1',
});

const Explanation = styled('div', {
  gridColumn: '1 / span 2',
  marginBottom: '$4',
});

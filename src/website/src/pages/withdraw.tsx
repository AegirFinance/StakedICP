import { GitHubLogoIcon, TwitterLogoIcon } from '@radix-ui/react-icons';
import React from 'react';
import { idlFactory, canisterId } from '../../../declarations/deposits';
import { AvailableLiquidityGraph, Deposits } from "../../../declarations/deposits/deposits.did.d.js";
import { getBackendActor }  from '../agent';
import { Flex, Header, HelpDialog, Input, Layout, NavToggle } from '../components';
import { DataTable, DataTableRow, DataTableLabel, DataTableValue } from '../components/DataTable';
import { useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { ConnectButton, useAccount } from "../wallet";

export function Withdraw() {
  return (
    <Wrapper>
      <Layout>
        <Header />
        <Flex css={{flexDirection:"column", alignItems:"center", padding: "$2"}}>
          <div>
            <NavToggle active="withdraw" />
            <WithdrawForm />
            <Subtitle>Your Withdrawals</Subtitle>
            <WithdrawalsList />
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

const FormWrapper = styled('form', {
  backgroundColor: '$slate3',
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
  padding: "$2",
  borderRadius: '$1',
  minWidth: "300px",
  '& > * + *': {
    marginTop: '$2',
  },
});

function parseFloat(str: string): number {
    str = str.trim();
    if (str == "") {
        return NaN;
    }
    return +str;
}

function WithdrawForm() {
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const [amount, setAmount] = React.useState("");
  const parsedAmount = React.useMemo(() => {
    if (!amount) {
        return 0;
    }
    const parsed = parseFloat(amount);
    if (parsed === NaN || parsed === +Infinity || parsed === -Infinity) {
        return 0;
    }
    return parsed;
  }, [amount]);
  const [showConfirmationDialog, setShowConfirmationDialog] = React.useState(false);

  return (
    <FormWrapper onSubmit={e => {
        e.preventDefault();
        setShowConfirmationDialog(!!(principal && parsedAmount >= 0));
    }}>
      <h3>Withdraw</h3>
      <Input
        type="text"
        name="amount" 
        value={amount ?? ""}
        placeholder="Amount"
        onChange={(e) => {
          setAmount(e.currentTarget.value);
        }} />
      {principal ? (
          <>
          <DataTable>
              <DataTableRow>
                  <DataTableLabel>Estimated Delay <HelpDialog aria-label="Estimated Delay Details">
                    {/* TODO: Fill in a better explanation here */}
                      <p>
                          This is the maximum time it may take for your withdrawal to be processed.
                      </p>
                  </HelpDialog></DataTableLabel>
                  {/* TODO: Fetch the delay for the amount */}
                  <DataTableValue><DelayStat amount={parsedAmount} /></DataTableValue>
              </DataTableRow>
              <DataTableRow>
                  <DataTableLabel>Exchange rate</DataTableLabel>
                  <DataTableValue>1 stICP = 1 ICP</DataTableValue>
              </DataTableRow>
              <DataTableRow>
                  <DataTableLabel>Transaction cost</DataTableLabel>
                  <DataTableValue>0 ICP</DataTableValue>
              </DataTableRow>
          </DataTable>
          <div>SHOW CONFIRMATION DIALOG</div>
          </>
      ) : (
        <ConnectButton />
      )}
    </FormWrapper>
  );
}

function DelayStat({amount}: {amount: number}) {
  const [liquidityGraph, setLiquidityGraph] = React.useState<AvailableLiquidityGraph|null>(null);

    useAsyncEffect(async () => {
        // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
        if (!canisterId) throw new Error("Canister not deployed");
        const contract = await getBackendActor<Deposits>({canisterId, interfaceFactory: idlFactory});

        const result = await contract.availableLiquidityGraph();
        setLiquidityGraph(result);
    }, []);

    if (amount === 0 || !liquidityGraph) {
        // TODO: proper loading indicator here
        return <>...</>;
    }

    // TODO: Calculate the delay for amount given
    return <>TODO: Delay here</>;
}

function WithdrawalsList() {
    return (
        <div />
    );
}

function Links() {
  return (
    <Flex css={{flexDirection:"row", justifyContent: "center", alignItems:"center", padding: "$2", '& > *': {margin: '$2'}}}>
      <a href="https://github.com/AegirFinance" title="Github"><GitHubLogoIcon /></a>
      <a href="https://twitter.com/StakedICP" title="Twitter"><TwitterLogoIcon /></a>
    </Flex>
  );
}


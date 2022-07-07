import { Principal } from '@dfinity/principal';
import { GitHubLogoIcon, TwitterLogoIcon } from '@radix-ui/react-icons';
import React from 'react';
import * as deposits from '../../../declarations/deposits';
import { AvailableLiquidityGraph, Deposits, Withdrawal } from "../../../declarations/deposits/deposits.did.d.js";
import { getBackendActor }  from '../agent';
import {
  Button,
  ConfirmationDialog,
  DialogDescription,
  DialogTitle,
  Flex,
  Header,
  HelpDialog,
  Input,
  Layout,
  NavToggle
} from '../components';
import { DataTable, DataTableRow, DataTableLabel, DataTableValue } from '../components/DataTable';
import * as format from "../format";
import { useAsyncEffect } from "../hooks";
import { styled } from '../stitches.config';
import { ConnectButton, useAccount, useCanister, useContext, useTransaction } from "../wallet";

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
  minHeight: "100vh",
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
    if (parsed === NaN || parsed === -NaN || parsed === +Infinity || parsed === -Infinity || parsed < 0) {
        return 0;
    }
    // TODO: Enforce max decimals here
    return parsed;
  }, [amount]);
  const [showConfirmationDialog, setShowConfirmationDialog] = React.useState(false);

  const [liquidityGraph, setLiquidityGraph] = React.useState<AvailableLiquidityGraph|null>(null);

  useAsyncEffect(async () => {
      // TODO: Have to use dfinity agent here, as we dont need the user's plug wallet connected.
      if (!deposits.canisterId) throw new Error("Canister not deployed");
      const contract = await getBackendActor<Deposits>({
        canisterId: deposits.canisterId,
        interfaceFactory: deposits.idlFactory,
      });

      const result = await contract.availableLiquidityGraph();
      setLiquidityGraph(result);
  }, []);

  const delay: bigint | undefined = React.useMemo(() => {
      if (!liquidityGraph) return undefined;
      if (parsedAmount === NaN || parsedAmount === -NaN || parsedAmount === +Infinity || parsedAmount === -Infinity || parsedAmount < 0) return undefined;
      let remaining: bigint = BigInt(Math.floor(parsedAmount*100_000_000));
      let maxDelay: bigint = BigInt(0);
      for (let [d, available] of liquidityGraph) {
          if (remaining <= 0) return maxDelay;
          maxDelay = d > maxDelay ? d : maxDelay;
          remaining -= available;
      };
      return maxDelay;
  }, [liquidityGraph, parsedAmount]);

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
                  <DataTableValue><DelayStat amount={parsedAmount} delay={delay} /></DataTableValue>
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
          <WithdrawDialog
            amount={parsedAmount}
            delay={delay}
            onOpenChange={(open: boolean) => {
              setShowConfirmationDialog(!!(principal && parsedAmount && open)); }
            }
            open={showConfirmationDialog}
            rawAmount={amount}
            />
        </>
      ) : (
        <ConnectButton />
      )}
    </FormWrapper>
  );
}

function DelayStat({amount, delay}: {amount: number; delay: bigint | undefined}) {

    if (amount === 0 || delay === undefined) {
        // TODO: proper loading indicator here
        return <>...</>;
    }

    // TODO: Calculate the delay for amount given
    return <>{format.delay(delay)}</>;
}

function WithdrawalsList() {
    const [data, setData] = React.useState<Withdrawal[] | null>(null);
    const [{ data: account }] = useAccount();
    const principal = account?.principal;
    const depositsCanister = useCanister<Deposits>({
        // TODO: handle missing canister id better
        canisterId: deposits.canisterId ?? "",
        interfaceFactory: deposits.idlFactory,
    });

    useAsyncEffect(async () => {
        if (!depositsCanister || !principal) return;
        let ws = await depositsCanister.listWithdrawals(Principal.fromText(principal));
        setData(ws);
    }, [!!depositsCanister, principal]);

    if (data === null) {
        // TODO: proper loading indicator
        return (
            <Flex>...</Flex>
        );
    }

    if (data.length === 0) {
        // TODO: proper loading indicator
        return (
            <Flex css={{flexDirection: "column", justifyContent: "flex-start"}}>
                <p>You have no withdrawals</p>
            </Flex>
        );
    }

    const available = data.map(w => w.available).reduce((s, a) => s+a, BigInt(0));

    return (
        <Flex css={{flexDirection: "column-reverse", justifyContent: "flex-start", '& > *': {marginTop: '$2', marginBottom: '$2'}}}>
            {available > BigInt(0) ? (
                <CompleteWithdrawalButton disabled={!principal} user={principal} available={available} />
            ) : null}
            {data.map(w => {
                let eta = w.readyAt.length > 0 ? w.readyAt[0] : w.expectedAt;
                return (
                    <Flex css={{
                        padding: '$1 $2',
                        backgroundColor: '$slate3',
                        borderRadius: '$1',
                        flexDirection: 'column',
                        justifyContent: 'flex-start',
                        alignItems: 'stretch',
                        }}>
                        <DataTable key={w.id}>
                            <DataTableRow>
                                <DataTableLabel>Total</DataTableLabel>
                                <DataTableValue>{format.units(w.total)} ICP</DataTableValue>
                            </DataTableRow>
                            <DataTableRow>
                                <DataTableLabel>Status</DataTableLabel>
                                <DataTableValue>{
                                    w.disbursed === w.total
                                        ? "Complete"
                                        : w.pending === BigInt(0)
                                        ? "Ready"
                                        : "Pending"
                                }</DataTableValue>
                            </DataTableRow>
                            <DataTableRow>
                                <DataTableLabel>ETA</DataTableLabel>
                                {/* TODO: Better timestamp formatting. Match how we show it when depositing */}
                                <DataTableValue>{
                                    eta
                                        ? <time dateTime={format.time(eta, 'UTC')}>{format.time(eta)}</time>
                                        : '...'
                                }</DataTableValue>
                            </DataTableRow>
                        </DataTable>
                    </Flex>
                );
            })}
        </Flex>
    );
}

interface WithdrawDialogParams {
  amount: number;
  delay?: bigint;
  onOpenChange: (open: boolean) => void;
  open: boolean;
  rawAmount: string;
}

const MINIMUM_WITHDRAWAL = 0.001;

function WithdrawDialog({
  amount,
  delay,
  onOpenChange,
  open,
  rawAmount,
}: WithdrawDialogParams) {
  const { setState: setGlobalState } = useContext();
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const depositsCanister = useCanister<Deposits>({
    // TODO: handle missing canister id better
    canisterId: deposits.canisterId ?? "",
    interfaceFactory: deposits.idlFactory,
  });

  useAsyncEffect(async () => {
      if (!depositsCanister) {
          return;
      }
      await depositsCanister.depositIcp();
  }, [!!depositsCanister]);

  const createWithdrawal = React.useCallback(async () => {
    if (!principal) {
      throw new Error("Wallet not connected");
    }
    if (rawAmount && amount < MINIMUM_WITHDRAWAL) {
      throw new Error(`Minimum withdrawal is ${MINIMUM_WITHDRAWAL} ICP`);
    }
    if (!amount) {
      throw new Error("Amount missing");
    }
    if (!depositsCanister) {
      throw new Error("Deposits canister missing");
    }

    const result = await depositsCanister.createWithdrawal(Principal.fromText(principal), BigInt(amount*100000000));
    if ('err' in result && result.err) {
      throw new Error(format.withdrawalsError(result.err));
    } else if (!('ok' in result) || !result.ok) {
      throw new Error("Withdrawal failed");
    }

    // Bump the cachebuster to refresh balances, and reload withdrawals list
    setGlobalState(x => ({...x, cacheBuster: x.cacheBuster+1}));
  }, [amount, !!depositsCanister]);

  return (
    <ConfirmationDialog
      open={open}
      onOpenChange={onOpenChange}
      onConfirm={createWithdrawal}
      button={"Start Withdrawal"}>
      {({state, error}) => error ? (
        <>
          <DialogTitle>Error</DialogTitle>
          <DialogDescription>{error}</DialogDescription>
        </>
      ) : state === "confirm" ? (
        <>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. Your {amount} stICP will be converted
            to {amount} ICP. They will be locked for up to {delay === undefined ? "<loading>" : format.delay(delay)} while this
            withdrawal is pending.
          </DialogDescription>
        </>
      ) : state === "pending" ? (
        <>
          <DialogTitle>Creating Withdrawal</DialogTitle>
          <DialogDescription>
            Creating withdrawal for {amount} stICP...
          </DialogDescription>
        </>
      ) : state === "complete" ? (
        <>
          <DialogTitle>Withdrawal Pending</DialogTitle>
          <DialogDescription>
            Successfully started withdrawal for {amount} stICP.
          </DialogDescription>
        </>
      ) : (
        <>
          <DialogTitle>Withdrawal Failed</DialogTitle>
          <DialogDescription>
            Failed to create withdrawal for {amount} stICP.
          </DialogDescription>
        </>
      )}
    </ConfirmationDialog>
  );
}

function Links() {
  return (
    <Flex css={{marginTop: '$4', flexDirection:"row", justifyContent: "center", alignItems:"center", padding: "$2", '& > *': {margin: '$2'}}}>
      <a href="https://github.com/AegirFinance" title="Github"><GitHubLogoIcon /></a>
      <a href="https://twitter.com/StakedICP" title="Twitter"><TwitterLogoIcon /></a>
    </Flex>
  );
}


function CompleteWithdrawalButton({
    disabled,
    user,
    available,
}: {
    disabled?: boolean;
    user: string;
    available: bigint;
}) {
    return (
        <Button disabled={disabled}>
            Transfer {format.units(available)} ICP
        </Button>
    );
}

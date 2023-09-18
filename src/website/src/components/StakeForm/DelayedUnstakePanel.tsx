import { Principal } from '@dfinity/principal';
import * as SliderPrimitive from '@radix-ui/react-slider';
import React from 'react';
import * as deposits from '../../../../declarations/deposits';
import { AvailableLiquidityGraph, Deposits, Withdrawal } from "../../../../declarations/deposits/deposits.did.d.js";
import * as token from "../../../../declarations/token";
import { getBackendActor }  from '../../agent';
import {
  ActivityIndicator,
  ConfirmationDialog,
  DataTable,
  DataTableLabel,
  DataTableRow,
  DataTableValue ,
  DialogDescription,
  DialogTitle,
  Flex,
  HelpDialog,
  Input,
  STICPLogo,
} from '../../components';
import * as format from "../../format";
import { ExchangeRate, useAsyncEffect } from "../../hooks";
import { styled } from '../../stitches.config';
import { ConnectButton, useAccount, useBalance, useCanister, useContext } from "../../wallet";
import { Price } from "./Price";
import { Slider } from "./Slider";

function parseFloat(str: string): number {
    try {
        str = str.trim();
        if (str == "") {
            return NaN;
        }
        return +str;
    } catch (err) {
        return NaN;
    }
}

export function DelayedUnstakePanel({rate}: {rate: ExchangeRate|null}) {
  const { state: { cacheBuster } } = useContext();
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const [{data: sticp}] = useBalance({ token: token.canisterId });
  const [amount, setAmount] = React.useState("");
  const parsedAmount : bigint = React.useMemo(() => {
    if (!amount) {
        return BigInt(0);
    }
    const parsed = parseFloat(amount);
    if (isNaN(parsed) || !isFinite(parsed) || parsed < 0) {
        return BigInt(0);
    }
    return BigInt(Math.floor(parsed*100_000_000));
  }, [amount]);
  const [showConfirmationDialog, setShowConfirmationDialog] = React.useState(false);

  const [withdrawals, setWithdrawals] = React.useState<Withdrawal[]|null>(null);
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

  const icpAmount: bigint | undefined = React.useMemo(() => {
      if (!rate) return undefined;
      // convert the user's chosen amount of stICP to unlocked ICP.
      return (parsedAmount * rate.totalIcp) / rate.stIcp;
  }, [parsedAmount, rate]);

  const delay: bigint | undefined = React.useMemo(() => {
      if (!liquidityGraph) return undefined;
      if (!rate) return undefined;
      // convert the user's chosen amount of stICP to unlocked ICP.
      let remaining = icpAmount;
      if (!remaining) return undefined;
      // Figure out the delay to unlock that amount of ICP
      let maxDelay: bigint = BigInt(60); // At least 1 minute
      for (let [d, available] of liquidityGraph) {
          if (remaining <= 0) return maxDelay;
          maxDelay = d > maxDelay ? d : maxDelay;
          remaining -= available;
      };
      return maxDelay;
  }, [liquidityGraph, icpAmount, rate]);

    const depositsCanister = useCanister<Deposits>({
        // TODO: handle missing canister id better
        canisterId: deposits.canisterId ?? "",
        interfaceFactory: deposits.idlFactory,
    });

    useAsyncEffect(async () => {
        if (!depositsCanister || !principal) {
            setWithdrawals(null);
            return;
        }
        let ws = await depositsCanister.listWithdrawals(Principal.fromText(principal));
        setWithdrawals(ws);
    }, [!!depositsCanister, principal, cacheBuster]);


  const available = withdrawals?.map(w => w.available).reduce((s, a) => s+a, BigInt(0));

  return (
    <FormWrapper onSubmit={e => {
        e.preventDefault();
        setShowConfirmationDialog(!!(principal && parsedAmount >= 0));
    }}>
      <h3>Start Withdrawal</h3>
      <Input
        prefix={
          <Flex css={{flexDirection: "row", alignItems: "center", "* + *": { marginLeft: '$2' }}}><STICPLogo height="24px" /><span>stICP</span></Flex>
        }
        type="text"
        name="amount" 
        value={amount ?? ""}
        placeholder="0.0"
        onChange={(e) => {
          setAmount(e.currentTarget.value);
        }} />
      <Price amount={icpAmount} />
      <Slider
        disabled={!principal || sticp === undefined}
        value={[Math.min(Number(parsedAmount), Number(sticp?.value ?? BigInt(0)))]}
        min={0}
        max={Number(sticp?.value ?? BigInt(100))}
        step={1}
        onValueChange={ns => {
            setAmount((ns[0] / 100_000_000).toFixed(sticp?.decimals ?? 8));
        }}
        aria-label="Amount" />
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
                  <DataTableValue>1 stICP = {rate ? format.units(rate.totalIcp*BigInt(100_000_000)/rate.stIcp, 8) : '...'} ICP</DataTableValue>
              </DataTableRow>
              <DataTableRow>
                  <DataTableLabel>Transaction cost</DataTableLabel>
                  <DataTableValue>0 ICP</DataTableValue>
              </DataTableRow>
          </DataTable>
          <UnstakeDialog
            amount={parsedAmount}
            disbursed={icpAmount ?? BigInt(0)}
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
      {!principal ? (
        <Flex css={{flexDirection: "column", justifyContent: "flex-start"}}>
          <p>Connect your wallet to see your withdrawals.</p>
        </Flex>
      ) : (
        <>
          <h3>Pending Withdrawals</h3>
          <PendingWithdrawalsList items={withdrawals?.filter(w => w.pending > BigInt(0))} />
          <h3>Ready Withdrawals</h3>
          {available === undefined
            ? <ActivityIndicator />
            : <CompleteUnstakeButton disabled={available <= BigInt(0)} amount={available} />}
        </>
      )}

    </FormWrapper>
  );
}

const FormWrapper = styled('form', {
  backgroundColor: '$slate1',
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
  padding: "$4",
  borderRadius: '$1',
  minWidth: "300px",
  boxShadow: '$large',
  '& > * + *': {
    marginTop: '$2',
  },
});

function DelayStat({amount, delay}: {amount: bigint; delay: bigint | undefined}) {
    if (amount === BigInt(0) || delay === undefined) {
        return <ActivityIndicator />;
    }

    return <>{format.delay(delay).split(' ').slice(0, 2).join(' ')}</>;
}

function PendingWithdrawalsList({items}: {items: Withdrawal[] | null | undefined}) {
    if (!items) {
        return (
            <Flex><ActivityIndicator /></Flex>
        );
    }

    if (items.length === 0) {
        return (
            <Flex css={{flexDirection: "column", justifyContent: "flex-start"}}>
                <p>You have no withdrawals</p>
            </Flex>
        );
    }

    const total = items.reduce((s, w) => s+w.pending, BigInt(0));

    return (
        <DataTable>
            {items.map(w => (
                <DataTableRow key={w.id}>
                    <DataTableLabel>
                        <time dateTime={format.time(w.expectedAt, 'UTC')}>{format.time(w.expectedAt)}</time>
                    </DataTableLabel>
                    <DataTableValue>{format.units(w.pending)} ICP</DataTableValue>
                </DataTableRow>
            ))}
            <DataTableRow key="total" css={{
                marginTop: '$1',
                paddingTop: '$1',
                borderWidth: '$1 0 0 0',
                borderColor: '$slate6',
                borderStyle: 'solid',
                }}>
                <DataTableLabel><b>Total</b></DataTableLabel>
                <DataTableValue>{format.units(total)} ICP</DataTableValue>
            </DataTableRow>
        </DataTable>
    );
}

interface UnstakeDialogParams {
  amount: bigint;
  disbursed: bigint;
  delay?: bigint;
  onOpenChange: (open: boolean) => void;
  open: boolean;
  rawAmount: string;
}

const MINIMUM_WITHDRAWAL = BigInt(100_000);

function UnstakeDialog({
  amount,
  disbursed,
  delay,
  onOpenChange,
  open,
  rawAmount,
}: UnstakeDialogParams) {
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
    if (rawAmount && disbursed < MINIMUM_WITHDRAWAL) {
      throw new Error(`Minimum withdrawal is ${format.units(MINIMUM_WITHDRAWAL, 8)} ICP`);
    }
    if (!amount) {
      throw new Error("Amount missing");
    }
    if (!depositsCanister) {
      throw new Error("Deposits canister missing");
    }

    // TODO: Support subaccount from wallet here.
    const result = await depositsCanister.createWithdrawal({owner:Principal.fromText(principal), subaccount: []}, amount);
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
            This action cannot be undone. Your {amount} stICP will be converted to {format.units(disbursed, 8)} ICP.
          </DialogDescription>
          <DialogDescription>
            {delay === undefined ? (
               <ActivityIndicator />
            ) : delay <= 0 ? (
              "They will be available instantly."
            ) : (
              `They will be locked for up to ${format.delay(delay)} while this withdrawal is pending.`
            )}
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

function CompleteUnstakeButton({
    amount,
    disabled,
}: {
    amount: bigint;
    disabled: boolean;
}) {
  const { setState: setGlobalState } = useContext();
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const depositsCanister = useCanister<Deposits>({
    // TODO: handle missing canister id better
    canisterId: deposits.canisterId ?? "",
    interfaceFactory: deposits.idlFactory,
  });
  const [to, setTo] = React.useState<string|null>(null);

  useAsyncEffect(async () => {
      if (!depositsCanister) {
          return;
      }
      await depositsCanister.depositIcp();
  }, [!!depositsCanister]);

  const completeUnstake = React.useCallback(async () => {
    if (!principal) {
      throw new Error("Wallet not connected");
    }
    if (amount < MINIMUM_WITHDRAWAL) {
      throw new Error(`Minimum withdrawal is ${format.units(MINIMUM_WITHDRAWAL, 8)} ICP`);
    }
    if (!depositsCanister) {
      throw new Error("Deposits canister missing");
    }

    const result = await depositsCanister.completeWithdrawal(Principal.fromText(principal), amount, to || principal);
    if ('err' in result && result.err) {
      throw new Error(format.withdrawalsError(result.err));
    } else if (!('ok' in result) || !result.ok) {
      throw new Error("Unstaking failed");
    }

    // Bump the cachebuster to refresh balances, and reload withdrawals list
    setGlobalState(x => ({...x, cacheBuster: x.cacheBuster+1}));
  }, [principal, amount, !!depositsCanister, to]);

  return (
    <ConfirmationDialog
      onConfirm={completeUnstake}
      disabled={disabled || amount <= 0}
      button={`Transfer ${format.units(amount)} ICP`}>
      {({state, error}) => error ? (
        <>
          <DialogTitle>Error</DialogTitle>
          <DialogDescription>{error}</DialogDescription>
        </>
      ) : state === "confirm" ? (
        <>
          <DialogTitle>Destination</DialogTitle>
          <DialogDescription css={{display: "flex", flexDirection: "column", alignItems: "stretch"}}>
            Please enter the destination address or principal to receive the ICP:
          </DialogDescription>
          <DialogDescription css={{display: "flex", flexDirection: "column", alignItems: "stretch"}}>
            <Input
              type="text"
              name="to" 
              value={to ?? ""}
              placeholder={`${format.shortPrincipal(principal)} (default)`}
              onChange={(e) => {
                  // TODO: Validate it is a real address here.
                  setTo(e.currentTarget.value);
              }} />
          </DialogDescription>
        </>
      ) : state === "pending" ? (
        <>
          <DialogTitle>Transfer Pending</DialogTitle>
          <DialogDescription>
            Transferring {format.units(amount)} ICP to {to || principal}...
          </DialogDescription>
        </>
      ) : state === "complete" ? (
        <>
          <DialogTitle>Transfer Complete</DialogTitle>
          <DialogDescription>
            Successfully transferred {format.units(amount)} ICP to {to || principal}.
          </DialogDescription>
        </>
      ) : (
        <>
          <DialogTitle>Transfer Failed</DialogTitle>
          <DialogDescription>
            Failed to transfer {format.units(amount)} to {to || principal}.
          </DialogDescription>
        </>
      )}
    </ConfirmationDialog>
  );
}

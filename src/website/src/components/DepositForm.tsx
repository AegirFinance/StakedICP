import React from 'react';
import * as deposits from "../../../declarations/deposits";
import { Deposits } from "../../../declarations/deposits/deposits.did";
import { useAsyncEffect, useReferralCode } from '../hooks';
import { styled } from '../stitches.config';
import { ConnectButton, useAccount, useCanister, useContext, useTransaction } from "../wallet";
import { ConfirmationDialog } from "./ConfirmationDialog";
import { DataTable, DataTableRow, DataTableLabel, DataTableValue } from './DataTable';
import { DialogDescription, DialogTitle } from "./Dialog";
import { HelpDialog } from './HelpDialog';
import { Input } from "./Input";

const Wrapper = styled('form', {
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

export function DepositForm() {
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const [amount, setAmount] = React.useState("");
  const deposit = React.useMemo(() => {
    if (!amount) {
        return 0;
    }
    const parsed = parseFloat(amount);
    if (parsed === NaN || parsed === +Infinity || parsed === -Infinity) {
        return 0;
    }
    return parsed;
  }, [amount]);
  const [showTransferDialog, setShowTransferDialog] = React.useState(false);
  const referralCode = useReferralCode();

  return (
    <Wrapper onSubmit={e => {
        e.preventDefault();
        setShowTransferDialog(!!(principal && deposit >= MINIMUM_DEPOSIT));
    }}>
      <h3>Deposit</h3>
      <Input
        type="text"
        name="amount" 
        value={amount ?? ""}
        placeholder="Amount"
        onChange={(e) => {
          setAmount(e.currentTarget.value);
        }} />
      {principal ? (
        <TransferDialog
          open={showTransferDialog}
          rawAmount={amount}
          amount={deposit}
          onOpenChange={(open: boolean) => {
            setShowTransferDialog(!!(principal && deposit && open));
          }}
          referralCode={referralCode}
          />
      ) : (
        <ConnectButton />
      )}
      <DataTable>
        <DataTableRow>
          <DataTableLabel>You will receive</DataTableLabel>
          <DataTableValue>{deposit >= MINIMUM_DEPOSIT ? deposit - FEE : 0} stICP</DataTableValue>
        </DataTableRow>
        <DataTableRow>
          <DataTableLabel>Exchange rate</DataTableLabel>
          <DataTableValue>1 ICP = 1 stICP</DataTableValue>
        </DataTableRow>
        <DataTableRow>
          <DataTableLabel>Transaction cost</DataTableLabel>
          <DataTableValue>{FEE} ICP</DataTableValue>
        </DataTableRow>
        <DataTableRow>
          {/* TODO: Add help text here, or better explanation */}
          <DataTableLabel>Reward fee <HelpDialog aria-label="Reward Fee Details">
            <p>
              Please note: this fee applies to staking rewards/earnings only, and is NOT taken from your staked amount. It is a fee on earnings only.
            </p>
          </HelpDialog></DataTableLabel>
          <DataTableValue>10%</DataTableValue>
        </DataTableRow>
      </DataTable>
    </Wrapper>
  );
}

interface TransferDialogParams {
  rawAmount: string;
  amount: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  referralCode: string | undefined;
}

const MINIMUM_DEPOSIT = 0.001;
const FEE = 0.0001;

function TransferDialog({
    rawAmount,
    amount,
    open,
    referralCode,
    onOpenChange,
}: TransferDialogParams) {
  const { setState: setGlobalState } = useContext();
  const [_, sendTransaction] = useTransaction();
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

  const deposit = React.useCallback(async () => {
    if (rawAmount && amount < MINIMUM_DEPOSIT) {
      throw new Error(`Minimum deposit is ${MINIMUM_DEPOSIT} ICP`);
    }
    if (!amount) {
      throw new Error("Amount missing");
    }
    if (!depositsCanister) {
      throw new Error("Deposits canister missing");
    }
    let to = await depositsCanister.getDepositAddress(referralCode ? [referralCode] : []);
    if (!to) {
      throw new Error("Failed to get the deposit address");
    }

    const { data: block_height, error } = await sendTransaction({
      request: {
        to,
        // TODO: Better number handling here than floats.
        amount: amount*100000000,
      },
    });
    if (error) {
      throw error;
    } else if (block_height === undefined) {
      throw new Error("Transfer failed");
    }

    await depositsCanister.depositIcp();

    // Bump the cachebuster to refresh balances
    setGlobalState(x => ({...x, cacheBuster: x.cacheBuster+1}));
  }, [amount, !!depositsCanister, referralCode]);

  return (
    <ConfirmationDialog
      open={open}
      onOpenChange={onOpenChange}
      onConfirm={deposit}
      button={"Deposit"}>
      {({state, error}) => error ? (
        <>
          <DialogTitle>Error</DialogTitle>
          <DialogDescription>{error}</DialogDescription>
        </>
      ) : state === "confirm" ? (
        <>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. Your {amount} ICP will immediately be
            converted to {amount} stICP, and cannot be converted back to ICP
            without an unstaking delay.
          </DialogDescription>
        </>
      ) : state === "pending" ? (
        <>
          <DialogTitle>Transfer Pending</DialogTitle>
          <DialogDescription>
            Converting {amount} ICP to {amount} stICP...
          </DialogDescription>
        </>
      ) : state === "complete" ? (
        <>
          <DialogTitle>Transfer Complete</DialogTitle>
          <DialogDescription>
            Successfully converted {amount} ICP to {amount} stICP.
          </DialogDescription>
        </>
      ) : (
        <>
          <DialogTitle>Transfer Failed</DialogTitle>
          <DialogDescription>
            Failed to convert {amount} ICP to {amount} stICP.
          </DialogDescription>
        </>
      )}
    </ConfirmationDialog>
  );
}

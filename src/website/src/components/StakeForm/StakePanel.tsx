import React from 'react';
import {
  ConfirmationDialog,
  DataTable,
  DataTableLabel,
  DataTableRow,
  DataTableValue,
  DialogDescription, DialogTitle,
  Flex,
  HelpDialog,
  ICPLogo,
  Input,
  STICPLogo,
} from '../index';
import { styled } from '../../stitches.config';
import * as deposits from "../../../../declarations/deposits";
import { Deposits } from "../../../../declarations/deposits/deposits.did";
import { useAsyncEffect, useReferralCode } from '../../hooks';
import { ConnectButton, useAccount, useCanister, useContext, useTransaction } from "../../wallet";
import { Price } from "./Price";


function parseFloat(str: string): number {
    str = str.trim();
    if (str == "") {
        return NaN;
    }
    return +str;
}

export function StakePanel() {
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const [amount, setAmount] = React.useState("");
  const stake = React.useMemo(() => {
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
    <FormWrapper onSubmit={e => {
        e.preventDefault();
        setShowTransferDialog(!!(principal && stake >= MINIMUM_DEPOSIT));
    }}>
      <Input
        prefix={
          <Flex css={{flexDirection: "row", alignItems: "center", "* + *": { marginLeft: '$2' }}}><ICPLogo height="24px" /><span>ICP</span></Flex>
        }
        type="text"
        name="amount" 
        value={amount ?? ""}
        placeholder="0.0"
        onChange={(e) => {
          setAmount(e.currentTarget.value);
        }} />
      <Price amount={stake ?? 0} />
      <h5 style={{marginBottom: '0.75rem'}}>You will receive</h5>
      <Input
        disabled
        prefix={
          <Flex css={{flexDirection: "row", alignItems: "center", "* + *": { marginLeft: '$2' }}}><STICPLogo height="24px" /><span>stICP</span></Flex>
        }
        type="text"
        name="receive"
        value={stake >= MINIMUM_DEPOSIT ? stake - FEE : 0}
        />
      <Price amount={Math.max((stake ?? 0) - FEE, 0)} />
      {principal ? (
        <TransferDialog
          open={showTransferDialog}
          rawAmount={amount}
          sentAmount={stake}
          receivedAmount={stake >= MINIMUM_DEPOSIT ? stake - FEE : 0}
          onOpenChange={(open: boolean) => {
            setShowTransferDialog(!!(principal && stake && open));
          }}
          referralCode={referralCode}
          />
      ) : (
        <ConnectButton />
      )}
      <DataTable>
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

interface TransferDialogParams {
  rawAmount: string;
  sentAmount: number;
  receivedAmount: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  referralCode: string | undefined;
}

const MINIMUM_DEPOSIT = 0.001;
const FEE = 0.0001;

function TransferDialog({
    rawAmount,
    sentAmount,
    receivedAmount,
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

  const onConfirm = React.useCallback(async () => {
    if (rawAmount && sentAmount < MINIMUM_DEPOSIT) {
      throw new Error(`Minimum deposit is ${MINIMUM_DEPOSIT} ICP`);
    }
    if (!sentAmount) {
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
        amount: sentAmount*100000000,
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
  }, [sentAmount, !!depositsCanister, referralCode]);

  return (
    <ConfirmationDialog
      open={open}
      onOpenChange={onOpenChange}
      onConfirm={onConfirm}
      button={"Stake"}>
      {({state, error}) => error ? (
        <>
          <DialogTitle>Error</DialogTitle>
          <DialogDescription>{error}</DialogDescription>
        </>
      ) : state === "confirm" ? (
        <>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. Your {sentAmount} ICP will immediately be
            converted to {receivedAmount} stICP, and cannot be converted back to ICP
            without an unstaking delay.
          </DialogDescription>
        </>
      ) : state === "pending" ? (
        <>
          <DialogTitle>Transfer Pending</DialogTitle>
          <DialogDescription>
            Converting {sentAmount} ICP to {receivedAmount} stICP...
          </DialogDescription>
        </>
      ) : state === "complete" ? (
        <>
          <DialogTitle>Transfer Complete</DialogTitle>
          <DialogDescription>
            Successfully converted {sentAmount} ICP to {receivedAmount} stICP.
          </DialogDescription>
        </>
      ) : (
        <>
          <DialogTitle>Transfer Failed</DialogTitle>
          <DialogDescription>
            Failed to convert {sentAmount} ICP to {receivedAmount} stICP.
          </DialogDescription>
        </>
      )}
    </ConfirmationDialog>
  );
}

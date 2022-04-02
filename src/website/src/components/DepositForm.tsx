import React from 'react';
import * as deposits from "../../../declarations/deposits";
import { Deposits, Invoice } from "../../../declarations/deposits/deposits.did";
import { styled } from '../stitches.config';
import { ConnectButton, useAccount, useCanister, useContext, useTransaction } from "../wallet";
import { Button } from "./Button";
import { DataTable, DataTableRow, DataTableLabel, DataTableValue } from './DataTable';
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "./Dialog";
import { Flex } from './Flex';
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

export function DepositForm() {
  const [{ data: account }] = useAccount();
  const principal = account?.principal;
  const [amount, setAmount] = React.useState("");
  const [showTransferDialog, setShowTransferDialog] = React.useState(false);

  return (
    <Wrapper>
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
          amount={Number.parseFloat(amount)}
          onOpenChange={(open: boolean) => {
            setShowTransferDialog(!!(principal && amount && open));
          }} />
      ) : (
        <ConnectButton />
      )}
      <DataTable>
        <DataTableRow>
          {/* TODO: Account for transaction fees here */}
          <DataTableLabel>You will receive</DataTableLabel>
          <DataTableValue>{amount || 0} stICP</DataTableValue>
        </DataTableRow>
        <DataTableRow>
          <DataTableLabel>Exchange rate</DataTableLabel>
          <DataTableValue>1 ICP = 1 stICP</DataTableValue>
        </DataTableRow>
        <DataTableRow>
          <DataTableLabel>Transaction cost</DataTableLabel>
          <DataTableValue>0.0001 ICP</DataTableValue>
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
  amount: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

const MINIMUM_DEPOSIT = 0.0001;

function TransferDialog({amount, open, onOpenChange: parentOnOpenChange}: TransferDialogParams) {
  const { setState: setGlobalState } = useContext();
  const [_, sendTransaction] = useTransaction();
  const depositsCanister = useCanister<Deposits>({
    // TODO: handle missing canister id better
    canisterId: deposits.canisterId ?? "",
    interfaceFactory: deposits.idlFactory,
  });
  const [state, setState] = React.useState<"confirm" | "pending" | "complete" | "rejected">("confirm");
  const error = React.useMemo(() => amount < MINIMUM_DEPOSIT && `Minimum deposit is ${MINIMUM_DEPOSIT} ICP`, [amount])
  const [invoice, setInvoice] = React.useState<Invoice | undefined>();

  const onOpenChange = React.useCallback((open: boolean) => {
    setState("confirm");
    parentOnOpenChange(open);
  }, [setState, parentOnOpenChange]);

  const deposit = React.useCallback(async () => {
    try {
      if (!amount) {
        throw new Error("Amount missing");
      }
      if (!depositsCanister) {
        throw new Error("Deposits canister missing");
      }

      setState("pending");

      const invoice = await depositsCanister.createInvoice();
      setInvoice(invoice);
      if (!invoice) {
          throw new Error("Error creating the invoice");
      }
      const { to, memo } = invoice;

      const { data: block_height, error } = await sendTransaction({
        request: {
          to,
          // TODO: Better number handling here than floats.
          amount: amount*100000000,
          opts: {
            memo: memo.toString(),
          },
        },
      });
      if (error) {
        throw error;
      } else if (block_height === undefined) {
        throw new Error("Transfer failed");
      }

      await depositsCanister.notify({ memo: memo.toString() as any, block_height });

      // Bump the cachebuster to refresh balances
      setGlobalState(x => ({...x, cacheBuster: x.cacheBuster+1}));
      setState("complete");
      setInvoice(undefined);
    } catch (err) {
      setState("rejected");
      throw err;
    }
  }, [amount]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button>Deposit</Button>
      </DialogTrigger>
      {error ? (
        <DialogContent>
          <DialogTitle>Error</DialogTitle>
          <DialogDescription>
            {error}
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="error" css={{marginRight: 25}} onClick={() => onOpenChange(false)}>
              Ok
              </Button>
            </DialogClose>
          </Flex>
        </DialogContent>
      ) : state === "confirm" ? (
        <DialogContent>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. Your {amount} ICP will immediately be
            converted to {amount} stICP, and cannot be converted back to ICP.
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="cancel" css={{marginRight: 25}} onClick={() => onOpenChange(false)}>
              Cancel
              </Button>
            </DialogClose>
            <Button onClick={() => deposit()}>Deposit</Button>
          </Flex>
        </DialogContent>
      ) : state === "pending" ? (
        <DialogContent>
          <DialogTitle>Transfer Pending</DialogTitle>
          {!invoice ? (
              <DialogDescription>
                Creating invoice...
              </DialogDescription>
          ) : (
              <DialogDescription>
                Converting {amount} ICP to {amount} stICP...
              </DialogDescription>
          )}
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild onClick={() => onOpenChange(false)}>
              <Button variant="cancel">Close</Button>
            </DialogClose>
          </Flex>
        </DialogContent>
      ) : state === "complete" ? (
        <DialogContent>
          <DialogTitle>Transfer Complete</DialogTitle>
          <DialogDescription>
            Successfully converted {amount} ICP to {amount} stICP.
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild onClick={() => onOpenChange(false)}>
              <Button>Done</Button>
            </DialogClose>
          </Flex>
        </DialogContent>
      ) : (
        <DialogContent>
          <DialogTitle>Transfer Failed</DialogTitle>
          <DialogDescription>
            <p>Failed to convert {amount} ICP to {amount} stICP.</p>
            {!!invoice && (
              <p>Please contact support with invoice number: {invoice.memo.toString()}</p>
            )}
          </DialogDescription>
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild onClick={() => onOpenChange(false)}>
              <Button>Done</Button>
            </DialogClose>
          </Flex>
        </DialogContent>
      )}
    </Dialog>
  );
}

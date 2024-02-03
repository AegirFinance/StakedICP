import { Principal } from '@dfinity/principal';
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
import { ExchangeRate, useAsyncEffect, useReferralCode } from '../../hooks';
import * as format from "../../format";
import { ConnectButton, useCanister, useConnect } from "../../wallet";
import * as deposits from "../../../../declarations/deposits";
import { Price } from "./Price";


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

export function StakePanel({ rate }: { rate: ExchangeRate | null }) {
    const { isConnected } = useConnect();
    const [amount, setAmount] = React.useState("");
    const stake: bigint = React.useMemo(() => {
        if (!amount) {
            return BigInt(0);
        }
        const parsed = parseFloat(amount);
        if (isNaN(parsed) || !isFinite(parsed) || parsed < 0) {
            return BigInt(0);
        }
        return BigInt(Math.floor(parsed * 100000000));
    }, [amount]);
    const [showTransferDialog, setShowTransferDialog] = React.useState(false);
    const referralCode = useReferralCode();

    const receivedAmount = rate && stake >= MINIMUM_DEPOSIT
        ? ((stake - FEE) * rate.stIcp) / rate.totalIcp
        : BigInt(0);

    return (
        <FormWrapper onSubmit={e => {
            e.preventDefault();
            setShowTransferDialog(!!(isConnected && stake >= MINIMUM_DEPOSIT));
        }}>
            <h3>Stake ICP</h3>
            <Input
                prefix={
                    <Flex css={{ flexDirection: "row", alignItems: "center", "* + *": { marginLeft: '$2' } }}>
                        <ICPLogo height="24px" />
                        <span>ICP</span>
                    </Flex>
                }
                type="text"
                name="amount"
                value={amount ?? ""}
                placeholder="0.0"
                onChange={(e) => {
                    setAmount(e.currentTarget.value);
                }} />
            <Price amount={stake ?? 0} />
            <h5 style={{ marginBottom: '0.75rem' }}>You will receive</h5>
            <Input
                disabled
                prefix={
                    <Flex css={{ flexDirection: "row", alignItems: "center", "* + *": { marginLeft: '$2' } }}><STICPLogo height="24px" /><span>stICP</span></Flex>
                }
                type="text"
                name="receive"
                value={format.units(receivedAmount, 8)}
            />
            <Price amount={stake > FEE ? stake - FEE : BigInt(0)} />
            <DataTable>
                <DataTableRow>
                    <DataTableLabel>Exchange rate</DataTableLabel>
                    <DataTableValue>1 ICP = {rate ? format.units(rate.stIcp*BigInt(100_000_000)/rate.totalIcp, 8) : '...'} stICP</DataTableValue>
                </DataTableRow>
                <DataTableRow>
                    <DataTableLabel>Transaction cost</DataTableLabel>
                    <DataTableValue>{format.units(FEE, 8)} ICP</DataTableValue>
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
            {isConnected ? (
                <TransferDialog
                    open={showTransferDialog}
                    rawAmount={amount}
                    sentAmount={stake}
                    receivedAmount={receivedAmount}
                    onOpenChange={(open: boolean) => {
                        setShowTransferDialog(!!(isConnected && stake && open));
                    }}
                    referralCode={referralCode}
                />
            ) : (
                <ConnectButton />
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

interface TransferDialogParams {
    rawAmount: string;
    sentAmount: bigint;
    receivedAmount: bigint;
    open: boolean;
    onOpenChange: (open: boolean) => void;
    referralCode: string | undefined;
}

const MINIMUM_DEPOSIT = BigInt(100_000);
const FEE: bigint = BigInt(10_000);

function TransferDialog({
    rawAmount,
    sentAmount,
    receivedAmount,
    open,
    referralCode,
    onOpenChange,
}: TransferDialogParams) {
    const [depositsCanister, {loading: depositsLoading}] = useCanister("deposits");
    const [nnsLedger, {loading: nnsLedgerLoading}] = useCanister("nnsLedger");

    useAsyncEffect(async () => {
        if (!depositsCanister || depositsLoading) {
            return;
        }
        await depositsCanister.depositIcp();
    }, [!!depositsCanister, depositsLoading]);

    const onConfirm = React.useCallback(async () => {
        if (rawAmount && sentAmount < MINIMUM_DEPOSIT) {
            throw new Error(`Minimum deposit is ${MINIMUM_DEPOSIT} ICP`);
        }
        if (!sentAmount) {
            throw new Error("Amount missing");
        }
        if (!depositsCanister || depositsLoading) {
            throw new Error("Deposits canister loading");
        }
        const owner = Principal.fromText(deposits.canisterId);
        if (owner.isAnonymous()) {
            throw new Error("Deposits canister loading");
        }
        let subaccount = await depositsCanister.getDepositSubaccount(referralCode ? [referralCode] : []);
        if (!subaccount) {
            throw new Error("Failed to get the deposit address");
        }

        if (!nnsLedger || nnsLedgerLoading) {
            throw new Error("NNS Ledger canister loading");
        }

        // TODO: Handle errors here
        const block_height = await nnsLedger.icrc1_transfer({
          from_subaccount: [],
          to: { owner, subaccount: [subaccount] },
          amount: sentAmount,
          fee: [],
          memo: [],
          created_at_time: [],
        });
        const error = null;
        if (error) {
            throw error;
        } else if (block_height === undefined) {
            throw new Error("Transfer failed");
        }

        await depositsCanister.depositIcp();
    }, [sentAmount, !!depositsCanister, referralCode]);

    return (
        <ConfirmationDialog
            open={open}
            onOpenChange={onOpenChange}
            onConfirm={onConfirm}
            button={"Stake"}>
            {({ state, error }) => error ? (
                <>
                    <DialogTitle>Error</DialogTitle>
                    <DialogDescription>{error}</DialogDescription>
                </>
            ) : state === "confirm" ? (
                <>
                    <DialogTitle>Are you sure?</DialogTitle>
                    <DialogDescription>
                        This action cannot be undone. Your {format.units(sentAmount, 8)} ICP will immediately be
                        converted to {format.units(receivedAmount, 8)} stICP, and cannot be converted back to ICP
                        without an unstaking delay.
                    </DialogDescription>
                </>
            ) : state === "pending" ? (
                <>
                    <DialogTitle>Transfer Pending</DialogTitle>
                    <DialogDescription>
                        Converting {format.units(sentAmount, 8)} ICP to {format.units(receivedAmount, 8)} stICP...
                    </DialogDescription>
                </>
            ) : state === "complete" ? (
                <>
                    <DialogTitle>Transfer Complete</DialogTitle>
                    <DialogDescription>
                        Successfully converted {format.units(sentAmount, 8)} ICP to {format.units(receivedAmount, 8)} stICP.
                    </DialogDescription>
                </>
            ) : (
                <>
                    <DialogTitle>Transfer Failed</DialogTitle>
                    <DialogDescription>
                        Failed to convert {format.units(sentAmount, 8)} ICP to {format.units(receivedAmount, 8)} stICP.
                    </DialogDescription>
                </>
            )}
        </ConfirmationDialog>
    );
}

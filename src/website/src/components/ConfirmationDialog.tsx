import React from 'react';
import { Button } from "./Button";
import { Dialog, DialogClose, DialogContent, DialogTrigger } from "./Dialog";
import { Flex } from './Flex';

export type ConfirmationDialogState = {
  state: "confirm" | "pending" | "complete" | "rejected",
  error?: string | null,
};

export interface ConfirmationDialogParams {
  button: string;
  children: React.ReactNode | ((props: ConfirmationDialogState) => React.ReactNode);
  disabled?: boolean;
  onConfirm: () => void | Promise<void>;
  onOpenChange?: (open: boolean) => void | Promise<void>;
  open?: boolean;
}

export function ConfirmationDialog({
    button,
    children,
    disabled=false,
    onConfirm: parentOnConfirm,
    onOpenChange: parentOnOpenChange,
    open,
}: ConfirmationDialogParams) {
  const [data, setData] = React.useState<ConfirmationDialogState>({state: "confirm"});
  const {state, error} = data;

  const onOpenChange = React.useCallback(async (open: boolean) => {
    setData({state: "confirm"});
    parentOnOpenChange && await parentOnOpenChange(open);
  }, [setData, parentOnOpenChange]);

  const onConfirm = React.useCallback(async () => {
    try {
      setData({state: "pending"});
      await parentOnConfirm();
      setData({state: "complete"});
    } catch (err) {
      let error: undefined | string = "";
      if (typeof err === "string") {
        error = err;
      } else if (err instanceof Error) {
        error = err.message;
      } else {
        error = "An unexpected error occured.";
      }
      setData({state: "rejected", error});
    }
  }, [setData, parentOnConfirm]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button disabled={disabled || !!error} variant={!!error ? "error" : undefined}>{error || button}</Button>
      </DialogTrigger>
      <DialogContent>
      {typeof children == 'function' ? children(data) : children}
      {error ? (
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="error" css={{marginRight: 25}} onClick={() => onOpenChange(false)}>
              Close
              </Button>
            </DialogClose>
          </Flex>
      ) : state === "confirm" ? (
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild>
              <Button variant="cancel" css={{marginRight: 25}} onClick={() => onOpenChange(false)}>
              Cancel
              </Button>
            </DialogClose>
            <Button onClick={onConfirm}>Confirm</Button>
          </Flex>
      ) : (
          <Flex css={{ justifyContent: 'flex-end'}}>
            <DialogClose asChild onClick={() => onOpenChange(false)}>
              <Button variant={state === "pending" ? "cancel" : undefined}>Close</Button>
            </DialogClose>
          </Flex>
      )}
      </DialogContent>
    </Dialog>
  );
}

import * as connect2ic from "@connect2ic/react";

// connect2ic provides a useWallet hook, but it doesn't seem to work correctly
// with bitfinity wallet. So I've aded a custom workaround here using their
// `useConnect` hook, which *does* seem to work with bitfinity.
export function useWallet(): readonly [{ principal?: string } | undefined] {
  const { isConnected, principal } = connect2ic.useConnect();
  return [isConnected ? { principal } : undefined];
}

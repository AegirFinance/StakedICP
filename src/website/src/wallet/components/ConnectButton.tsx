import "@connect2ic/core/style.css";

import * as connect2ic from "@connect2ic/react";

export type ConnectButtonProperties = Parameters<typeof connect2ic.ConnectButton>[0];

export function ConnectButton(props: ConnectButtonProperties) {
  return <connect2ic.ConnectButton {...props} />;
}

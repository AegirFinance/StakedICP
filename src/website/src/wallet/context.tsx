import React from "react";
import { useLocalStorage } from "../hooks";
import { BitfinityConnector, Connector, Data, PlugConnector } from "./connectors";

type State = {
  /** Flag for triggering refetch */
  cacheBuster: number;
  /** Flag for when connection is in progress */
  connecting?: boolean;
  /** Active connector */
  connector?: Connector;
  /** Active data */
  data?: Data|null;
  error?: Error;
};

type ContextValue = {
  state: State & {
    /** Connectors used for linking accounts */
    connectors: Connector[]
  }
  setState: React.Dispatch<React.SetStateAction<State>>
  setLastUsedConnector: (newValue: string | null) => void
};

const Context = React.createContext<ContextValue | null>(null);

export interface Props {
  children?: React.ReactNode
  /** Enables reconnecting to last used connector on mount */
  autoConnect?: boolean
  /**
   * Key for saving connector preference to browser
   * @default 'wagmi.wallet'
   */
  connectorStorageKey?: string
  /**
   * Connectors used for linking accounts
   * @default [new BitfinityConnector(), new PlugConnector()]
   */
  connectors?: Connector[] | (() => Connector[])

  whitelist?: string[];
  host?: string;
  dev?: boolean;
}

// Provider to wrap the app in to make wallet data available globally.
export function Provider({
  autoConnect = false,
  children,
  connectorStorageKey = 'icp-react.wallet',
  whitelist,
  host,
  dev,
  connectors: connectors_ = [new BitfinityConnector({whitelist, host, dev}), new PlugConnector({whitelist, host})],
}: Props) {
  const [lastUsedConnector, setLastUsedConnector] = useLocalStorage<
    string | null
  >(connectorStorageKey);
  const [state, setState] = React.useState<State>({
    cacheBuster: 1,
    connecting: autoConnect,
  });

  const connectors = React.useMemo(() => {
    if (typeof connectors_ !== 'function') {
      return connectors_;
    }
    return connectors_();
  }, [connectors_]);

  // Attempt to connect on mount
  /* eslint-disable react-hooks/exhaustive-deps */
  React.useEffect(() => {
    if (!autoConnect) {
      return;
    }
    (async () => {
      setState((x) => ({ ...x, connecting: true }));
      const sorted = lastUsedConnector
        ? [...connectors].sort((x) => (x.name === lastUsedConnector ? -1 : 1))
        : connectors;
      for (const connector of sorted) {
        if (!connector.ready || !connector.isAuthorized) continue;
        const isAuthorized = await connector.isAuthorized();
        if (!isAuthorized) continue;

        const data = await connector.connect();
        setState((x) => ({ ...x, connector, data }));
        break;
      }
      setState((x) => ({ ...x, connecting: false }));
    })();
  }, [])
  /* eslint-enable react-hooks/exhaustive-deps */

  // Make sure connectors close
  React.useEffect(() => {
    return () => {
      if (!state.connector) return;
      state.connector.disconnect();
    }
  }, [state.connector]);

  // TODO: Watch connector for events

  const value = {
    state: {
      cacheBuster: state.cacheBuster,
      connecting: state.connecting,
      connectors,
      connector: state.connector,
      data: state.data,
    },
    setState,
    setLastUsedConnector,
  };

  return (
    <Context.Provider value={value}>
      {children}
    </Context.Provider>
  );
}

export function useContext() {
  const context = React.useContext(Context);
  if (!context) {
    throw Error('Must be used within Provider');
  }
  return context;
}


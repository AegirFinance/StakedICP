import { ActorSubclass } from "@dfinity/agent";
import { CreateActor } from "plug";
import React from 'react';
import { useContext } from "../context";
import { useAsyncEffect } from "../../hooks";

export function useCanister<T>(options: CreateActor<T>): ActorSubclass<T> | undefined {
  const { state: { connector } } = useContext();
  const [state, setState] = React.useState<undefined | ActorSubclass<T>>(undefined);


   /* eslint-disable react-hooks/exhaustive-deps */
  // TODO: Poll this periodically to refresh, or watch for new blocks
  useAsyncEffect(async () => {
    setState(await connector?.createActor(options));
  }, [options.actor, options.agent, options.canisterId, options.interfaceFactory]);
  /* eslint-enable react-hooks/exhaustive-deps */

   return state;
}

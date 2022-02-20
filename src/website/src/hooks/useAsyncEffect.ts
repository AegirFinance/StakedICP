import React, { EffectCallback, DependencyList } from "react";

export type AsyncEffectCallback =
  | EffectCallback
  | (() => Promise<ReturnType<EffectCallback>>);

export function useAsyncEffect(effect: AsyncEffectCallback, deps?: DependencyList) {
  React.useEffect(() => {
    const result = Promise.resolve(effect());
    return () => {
      Promise.resolve(result).then(f => f && f());
    };
  }, deps);
}

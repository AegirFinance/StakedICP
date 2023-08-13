import React from "react";
import { AsyncEffectCallback } from "./useAsyncEffect";

export function useInterval(effect: AsyncEffectCallback, delay: number) {
  const savedCallback = React.useRef<AsyncEffectCallback|null>(null);
  React.useEffect(() => {
    savedCallback.current = effect;
  }, [effect]);
  React.useEffect(() => {
    const tick = () => savedCallback.current && savedCallback.current();
    if (delay !== null) {
        const id = setInterval(tick, delay);
        return () => clearInterval(id);
    }
  }, [effect, delay]);
}

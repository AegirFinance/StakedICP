import { ActorSubclass } from "@dfinity/agent";
import * as connect2ic from "@connect2ic/react";

export function useCanister<T>(
  canisterName: string,
  options?: { mode: "auto" | "anonymous" | "connected"}
): readonly [ActorSubclass<T>, { canisterDefinition: any; error: any; loading: boolean }] {
  const [actor, extra] = connect2ic.useCanister(canisterName, options);
  return [actor as unknown as ActorSubclass<T>, extra];
}

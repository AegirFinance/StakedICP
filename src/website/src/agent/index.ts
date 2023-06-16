import { Actor, HttpAgent, ActorSubclass } from '@dfinity/agent';
import { CreateActor } from "plug";

export async function getBackendActor<T>({canisterId, interfaceFactory}: Pick<CreateActor<T>, "canisterId" | "interfaceFactory">): Promise<ActorSubclass<T>> {
  if (!canisterId) {
    throw new Error("Canister not deployed");
  }

  const agent = new HttpAgent(
    process.env.NODE_ENV === "production"
      ? { host: "https://icp-api.io" }
      : { host: "http://localhost:8080" }
  );

  // for local development only, this must not be used for production
  if (process.env.NODE_ENV === 'development') {
    await agent.fetchRootKey();
  }

  return Actor.createActor<T>(interfaceFactory, { agent, canisterId });
};

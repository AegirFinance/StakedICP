import { Actor, HttpAgent, ActorSubclass } from '@dfinity/agent';
import { CreateActor } from "plug";

// TODO: Need the proper host url here for production
let agentOptions = { host: process.env.NETWORK ?? 'http://localhost:8000' };

export async function getBackendActor<T>({canisterId, interfaceFactory}: Pick<CreateActor<T>, "canisterId" | "interfaceFactory">): Promise<ActorSubclass<T>> {
  if (!canisterId) {
    throw new Error("Canister not deployed");
  }

  const agent = new HttpAgent(agentOptions);
  // for local development only, this must not be used for production
  if (process.env.NODE_ENV === 'development') {
    await agent.fetchRootKey();
  }

  return Actor.createActor<T>(interfaceFactory, { agent, canisterId });
};

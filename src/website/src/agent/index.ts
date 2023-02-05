import { Actor, HttpAgent, ActorSubclass } from '@dfinity/agent';
import { CreateActor } from "plug";

export async function getBackendActor<T>({canisterId, interfaceFactory}: Pick<CreateActor<T>, "canisterId" | "interfaceFactory">): Promise<ActorSubclass<T>> {
  if (!canisterId) {
    throw new Error("Canister not deployed");
  }

  const host = process.env.NODE_ENV === "production"
    ? `https://${canisterId}.ic0.app`
    : "http://localhost:8000";
  const agent = new HttpAgent({ host });
  // for local development only, this must not be used for production
  if (process.env.NODE_ENV === 'development') {
    await agent.fetchRootKey();
  }

  return Actor.createActor<T>(interfaceFactory, { agent, canisterId });
};

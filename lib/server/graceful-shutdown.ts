import type { Server } from "node:http";

import {
  beginLiveAudioDrain,
  broadcastCoordinatorDisconnect,
  forceCloseRemainingLiveAudioConnections,
} from "@/lib/live-audio/live-audio-connection-registry";
import { logLiveAudio } from "@/lib/live-audio/live-audio-log";

export const GRACEFUL_SHUTDOWN_DRAIN_MS = 10_000;

function resolveGracefulShutdownDrainMs(): number {
  const parsed = Number.parseInt(
    process.env.VOICEMEMORY_GRACEFUL_SHUTDOWN_DRAIN_MS ?? "",
    10,
  );
  return Number.isFinite(parsed) && parsed > 0
    ? parsed
    : GRACEFUL_SHUTDOWN_DRAIN_MS;
}

let shutdownStarted = false;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function registerGracefulShutdown(server: Server): void {
  const handleSignal = (signal: NodeJS.Signals) => {
    void runGracefulShutdown(server, signal);
  };

  process.once("SIGTERM", handleSignal);
  process.once("SIGINT", handleSignal);
}

export async function runGracefulShutdown(
  server: Server,
  signal: NodeJS.Signals,
): Promise<void> {
  if (shutdownStarted) {
    return;
  }
  shutdownStarted = true;

  logLiveAudio(`graceful shutdown started signal=${signal}`);

  beginLiveAudioDrain();
  server.close();

  broadcastCoordinatorDisconnect();
  await sleep(resolveGracefulShutdownDrainMs());
  forceCloseRemainingLiveAudioConnections();

  logLiveAudio(`graceful shutdown complete signal=${signal}`);
  process.exit(0);
}

export function resetGracefulShutdownForTest(): void {
  shutdownStarted = false;
}

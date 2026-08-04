import type { WebSocket } from "ws";

import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import type { LiveAudioClientSocket } from "@/lib/live-audio/ws-proxy-connection";

export const LIVE_AUDIO_COORDINATOR_DISCONNECT = "coordinator_disconnect";

type ActiveLiveAudioConnection = {
  sessionId: string;
  client: LiveAudioClientSocket;
  ws: WebSocket;
};

let draining = false;
const activeConnections = new Set<ActiveLiveAudioConnection>();

export function isLiveAudioDraining(): boolean {
  return draining;
}

export function activeLiveAudioConnectionCount(): number {
  return activeConnections.size;
}

export function registerLiveAudioConnection(
  connection: ActiveLiveAudioConnection,
): () => void {
  activeConnections.add(connection);
  return () => {
    activeConnections.delete(connection);
  };
}

export function beginLiveAudioDrain(): void {
  if (draining) {
    return;
  }
  draining = true;
  logLiveAudio(
    `drain started activeConnections=${activeConnections.size} reason=${LIVE_AUDIO_COORDINATOR_DISCONNECT}`,
  );
}

export function broadcastCoordinatorDisconnect(): number {
  const payload = JSON.stringify({
    error: {
      message: LIVE_AUDIO_COORDINATOR_DISCONNECT,
      code: LIVE_AUDIO_COORDINATOR_DISCONNECT,
    },
  });

  let notified = 0;
  for (const connection of activeConnections) {
    try {
      connection.client.send(payload);
      connection.client.close(1001, LIVE_AUDIO_COORDINATOR_DISCONNECT);
      notified++;
    } catch {
      logLiveAudio("drain notify failed reason=send_failed");
      try {
        connection.ws.terminate();
      } catch {
        // Best-effort shutdown during container drain.
      }
    }
  }

  logLiveAudio(
    `drain broadcast reason=${LIVE_AUDIO_COORDINATOR_DISCONNECT} notified=${notified}`,
  );
  return notified;
}

export async function waitForLiveAudioConnectionsClosed(
  timeoutMs: number,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (activeConnections.size > 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  logLiveAudio(
    `drain wait complete remainingConnections=${activeConnections.size} timeoutMs=${timeoutMs}`,
  );
}

export function forceCloseRemainingLiveAudioConnections(): number {
  let closed = 0;
  for (const connection of activeConnections) {
    try {
      connection.ws.terminate();
      closed++;
    } catch {
      // Best-effort forced shutdown after drain window.
    }
  }
  activeConnections.clear();
  if (closed > 0) {
    logLiveAudio(`drain force closed remaining=${closed}`);
  }
  return closed;
}

export function resetLiveAudioConnectionRegistryForTest(): void {
  draining = false;
  activeConnections.clear();
}

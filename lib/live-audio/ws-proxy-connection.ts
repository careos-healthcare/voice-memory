import {
  GeminiLiveProxy,
  type GeminiLiveProxyOptions,
} from "@/lib/live-audio/gemini-live-proxy";
import { logLiveAudio, logLiveAudioCritical } from "@/lib/live-audio/live-audio-log";

const DEFAULT_LIVE_MODEL_ID =
  process.env.VOICEMEMORY_GEMINI_LIVE_MODEL ??
  "gemini-2.5-flash-native-audio-preview-12-2025";

export interface LiveAudioClientSocket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
  onMessage(handler: (data: string) => void): void;
  onClose(handler: () => void): void;
  onError(handler: (error: unknown) => void): void;
}

export type LiveAudioProxyFactory = (
  options: GeminiLiveProxyOptions,
) => GeminiLiveProxy;

/**
 * Bridges one authenticated client WebSocket to Gemini Live upstream.
 *
 * Server sends setup upstream; client must wait for setupComplete before audio.
 */
export async function runLiveAudioProxyConnection(input: {
  client: LiveAudioClientSocket;
  sessionId: string;
  subject: string;
  apiKey: string;
  modelId?: string;
  voiceName?: string;
  createProxy?: LiveAudioProxyFactory;
}): Promise<void> {
  const proxy =
    input.createProxy?.({
      apiKey: input.apiKey,
      modelId: input.modelId ?? DEFAULT_LIVE_MODEL_ID,
      voiceName: input.voiceName,
    }) ??
    new GeminiLiveProxy({
      apiKey: input.apiKey,
      modelId: input.modelId ?? DEFAULT_LIVE_MODEL_ID,
      voiceName: input.voiceName,
    });

  let closed = false;
  const closeAll = (reason: string) => {
    if (closed) return;
    closed = true;
    proxy.close();
    input.client.close(1000, reason);
    logLiveAudio(`proxy closed sessionId=${input.sessionId} reason=${reason}`);
  };

  input.client.onClose(() => closeAll("client_closed"));
  input.client.onError((error) => {
    logLiveAudioCritical("client websocket error", error);
    closeAll("client_error");
  });

  try {
    await proxy.connect({
      onServerEvents: () => {},
      onClientRelay: (rawJson) => {
        if (!closed) {
          input.client.send(rawJson);
        }
      },
    });
    logLiveAudio(
      `proxy connected sessionId=${input.sessionId} subject=${input.subject}`,
    );
  } catch (error) {
    logLiveAudioCritical("proxy connect failed", error);
    if (!closed) {
      input.client.send(
        JSON.stringify({ error: { message: "upstream_connect_failed" } }),
      );
    }
    closeAll("upstream_connect_failed");
    return;
  }

  input.client.onMessage((rawJson) => {
    if (closed) return;

    let parsed: unknown;
    try {
      parsed = JSON.parse(rawJson);
    } catch {
      input.client.send(JSON.stringify({ error: { message: "invalid_client_json" } }));
      return;
    }

    if (
      typeof parsed === "object" &&
      parsed !== null &&
      !Array.isArray(parsed) &&
      "setup" in parsed
    ) {
      logLiveAudio(
        `reject client setup frame sessionId=${input.sessionId} reason=client_setup_not_allowed`,
      );
      input.client.send(
        JSON.stringify({ error: { message: "client_setup_not_allowed" } }),
      );
      return;
    }

    const relay = proxy.relayClientJson(rawJson);
    if (!relay.ok) {
      logLiveAudio(
        `reject client frame sessionId=${input.sessionId} reason=${relay.reason}`,
      );
      if (relay.reason === "awaiting_setup_complete") {
        input.client.send(
          JSON.stringify({ error: { message: relay.reason } }),
        );
      }
    }
  });
}

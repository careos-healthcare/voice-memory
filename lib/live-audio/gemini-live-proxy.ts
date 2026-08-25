import { logLiveAudio, logLiveAudioCritical } from "@/lib/live-audio/live-audio-log";
import {
  buildLiveSetupMessage,
  parseLiveClientMessage,
  parseLiveServerJson,
  serializeLiveClientMessage,
  type LiveServerEvent,
} from "@/lib/live-audio/protocol";
import { geminiLiveWebSocketUrl } from "@/lib/live-audio/upstream-url";

export interface GeminiLiveProxyOptions {
  modelId?: string;
  voiceName?: string;
  apiKey?: string;
  connectWebSocket?: (url: string) => Promise<GeminiLiveWebSocket>;
}

export interface GeminiLiveWebSocket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
  onMessage(handler: (data: string) => void): void;
  onError(handler: (error: unknown) => void): void;
  onClose(handler: () => void): void;
}

export type GeminiLiveProxyState =
  | "idle"
  | "connecting"
  | "awaiting_setup_complete"
  | "ready"
  | "closed"
  | "error";

/**
 * Server-side Gemini Live upstream session.
 *
 * Sends the mandatory setup frame on connect and relays validated client JSON
 * once setup completes. Intended for use behind `/api/live-audio/ws`.
 */
export class GeminiLiveProxy {
  private _state: GeminiLiveProxyState = "idle";
  private _socket: GeminiLiveWebSocket | null = null;
  private _setupSent = false;
  private _setupComplete = false;

  constructor(private readonly options: GeminiLiveProxyOptions = {}) {}

  get state(): GeminiLiveProxyState {
    return this._state;
  }

  get setupComplete(): boolean {
    return this._setupComplete;
  }

  async connect(handlers: {
    onServerEvents: (events: LiveServerEvent[]) => void;
    onClientRelay?: (rawJson: string) => void;
    onStateChange?: (state: GeminiLiveProxyState) => void;
  }): Promise<void> {
    if (this._state !== "idle" && this._state !== "closed" && this._state !== "error") {
      throw new Error("GeminiLiveProxy already active");
    }

    this.setState("connecting", handlers.onStateChange);
    const apiKey = this.options.apiKey?.trim();
    if (!apiKey) {
      throw new Error("GeminiLiveProxy requires apiKey option");
    }
    const url = geminiLiveWebSocketUrl(apiKey);
    const connect = this.options.connectWebSocket ?? connectNativeWebSocket;

    try {
      this._socket = await connect(url);
      this._setupSent = false;
      this._setupComplete = false;

      this._socket.onMessage((raw) => {
        handlers.onClientRelay?.(raw);
        const events = parseLiveServerJson(raw);
        handlers.onServerEvents(events);
        if (events.some((event) => event.type === "setup_complete")) {
          this._setupComplete = true;
          this.setState("ready", handlers.onStateChange);
          logLiveAudio("setupComplete received from upstream");
        }
      });
      this._socket.onError((error) => {
        logLiveAudioCritical("upstream websocket error", error);
        this.setState("error", handlers.onStateChange);
      });
      this._socket.onClose(() => {
        this.setState("closed", handlers.onStateChange);
      });

      const setup = buildLiveSetupMessage({
        modelId: this.options.modelId,
        voiceName: this.options.voiceName,
      });
      this.sendUpstream(setup as unknown as Record<string, unknown>);
      this._setupSent = true;
      this.setState("awaiting_setup_complete", handlers.onStateChange);
      logLiveAudio(
        `upstream connected model=${setup.setup.model} setupSent=${this._setupSent}`,
      );
    } catch (error) {
      logLiveAudioCritical("upstream connect failed", error);
      this.setState("error", handlers.onStateChange);
      throw error;
    }
  }

  relayClientJson(rawJson: string): { ok: true } | { ok: false; reason: string } {
    if (!this._socket || this._state === "closed" || this._state === "error") {
      return { ok: false, reason: "upstream_not_connected" };
    }
    if (!this._setupComplete) {
      return { ok: false, reason: "awaiting_setup_complete" };
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(rawJson);
    } catch {
      return { ok: false, reason: "invalid_client_json" };
    }

    const validated = parseLiveClientMessage(parsed);
    if (!validated.ok) {
      logLiveAudio(`reject client frame reason=${validated.reason}`);
      return validated;
    }

    this._socket.send(serializeLiveClientMessage(validated.message));
    return { ok: true };
  }

  close(): void {
    this._socket?.close(1000, "proxy_closed");
    this._socket = null;
    this._state = "closed";
  }

  private sendUpstream(message: Record<string, unknown>): void {
    if (!this._socket) {
      throw new Error("upstream socket missing");
    }
    this._socket.send(JSON.stringify(message));
  }

  private setState(
    state: GeminiLiveProxyState,
    onStateChange?: (state: GeminiLiveProxyState) => void,
  ): void {
    this._state = state;
    onStateChange?.(state);
  }
}

async function connectNativeWebSocket(url: string): Promise<GeminiLiveWebSocket> {
  const socket = new WebSocket(url);
  await new Promise<void>((resolve, reject) => {
    socket.addEventListener("open", () => resolve(), { once: true });
    socket.addEventListener("error", () => reject(new Error("websocket_open_failed")), {
      once: true,
    });
  });

  return {
    send(data) {
      socket.send(data);
    },
    close(code, reason) {
      socket.close(code, reason);
    },
    onMessage(handler) {
      socket.addEventListener("message", (event) => {
        if (typeof event.data === "string") {
          handler(event.data);
          return;
        }
        if (event.data instanceof ArrayBuffer) {
          handler(Buffer.from(event.data).toString("utf8"));
        }
      });
    },
    onError(handler) {
      socket.addEventListener("error", (event) => handler(event));
    },
    onClose(handler) {
      socket.addEventListener("close", () => handler(), { once: true });
    },
  };
}

export type { GeminiLiveProxyState };

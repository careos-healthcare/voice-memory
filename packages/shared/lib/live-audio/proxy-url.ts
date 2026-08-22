import { LIVE_AUDIO_PROXY_WS_PATH } from "@/lib/live-audio/constants";

/** Convert an HTTP(S) origin to WS(S) for WebSocket client connections. */
export function httpOriginToWebSocketOrigin(origin: string): string {
  return origin.replace(/^http/i, "ws");
}

/** Build the backend proxy WebSocket URL from an HTTP request origin. */
export function buildProxyWebSocketUrl(httpOrigin: string): string {
  return `${httpOriginToWebSocketOrigin(httpOrigin)}${LIVE_AUDIO_PROXY_WS_PATH}`;
}

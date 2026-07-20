import { NextResponse } from "next/server";

import {
  LIVE_AUDIO_PROXY_WS_PATH,
  LIVE_SESSION_TOKEN_QUERY_PARAM,
} from "@/lib/live-audio/constants";
import { buildProxyWebSocketUrl } from "@/lib/live-audio/proxy-url";

export const runtime = "nodejs";

/** Discovery endpoint — the live proxy uses WebSocket upgrade on this path. */
export async function GET(request: Request) {
  const origin = new URL(request.url).origin;

  return NextResponse.json({
    route: LIVE_AUDIO_PROXY_WS_PATH,
    protocol: "websocket",
    methods: ["GET (upgrade)"],
    sessionTokenQueryParam: LIVE_SESSION_TOKEN_QUERY_PARAM,
    proxyWebSocketUrl: buildProxyWebSocketUrl(origin),
    mintSessionRoute: "/api/live-audio/session",
    note:
      "Mint a session via POST /api/live-audio/session, then connect to proxyWebSocketUrl with sessionToken. " +
      "Use the custom Node server (server.entry.ts / dist/main.js) for WebSocket upgrades in local/self-hosted environments.",
    code: "WEBSOCKET_UPGRADE_REQUIRED",
  });
}

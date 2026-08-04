import { CLOUD_RELAY_WS_PATH } from "@/lib/sync/cloud-relay-ws-upgrade";
import { cloudRelaySecurityHeaders } from "@/lib/sync/cloud-relay-contract";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** WebSocket discovery; upgrades are handled by the custom Node server. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const protocol = url.protocol === "https:" ? "wss:" : "ws:";
  return Response.json(
    {
      ok: false,
      code: "WEBSOCKET_UPGRADE_REQUIRED",
      path: CLOUD_RELAY_WS_PATH,
      tokenQueryParameter: "token",
      url: `${protocol}//${url.host}${CLOUD_RELAY_WS_PATH}`,
      note: "Use a short-lived token issued by POST /api/sync-relay with action=issue_token.",
    },
    {
      status: 426,
      headers: {
        ...cloudRelaySecurityHeaders(),
        Upgrade: "websocket",
      },
    },
  );
}

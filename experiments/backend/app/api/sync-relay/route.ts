import { getServerSession } from "@/lib/server/session";
import {
  listCloudRelayDevices,
  pushCloudRelayEnvelopes,
  registerCloudRelayDevice,
  revokeCloudRelayDevice,
  takeCloudRelayEnvelopes,
} from "@/lib/server/cloud-relay-store";
import {
  bearerToken,
  mintCloudRelayToken,
  verifyCloudRelayToken,
} from "@/lib/sync/cloud-relay-auth";
import {
  CLOUD_RELAY_MAX_BATCH_BYTES,
  cloudRelaySecurityHeaders,
  parseCloudRelayIssueTokenRequest,
  parseCloudRelayPushRequest,
} from "@/lib/sync/cloud-relay-contract";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_REQUEST_BYTES = Math.ceil(CLOUD_RELAY_MAX_BATCH_BYTES * 1.5) + 8192;
const DEVICE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;

function json(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: cloudRelaySecurityHeaders(),
  });
}

function relayAccess(request: Request) {
  const token = bearerToken(request);
  return token ? verifyCloudRelayToken(token) : null;
}

async function requestJson(request: Request): Promise<unknown> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_REQUEST_BYTES) {
    throw new Error("Relay request exceeds storage limits.");
  }
  const body = await request.text();
  if (Buffer.byteLength(body, "utf8") > MAX_REQUEST_BYTES) {
    throw new Error("Relay request exceeds storage limits.");
  }
  return JSON.parse(body);
}

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await requestJson(request);
  } catch {
    return json({ ok: false, code: "INVALID_RELAY_REQUEST" }, 400);
  }

  if (
    body &&
    typeof body === "object" &&
    !Array.isArray(body) &&
    (body as Record<string, unknown>).action === "issue_token"
  ) {
    const session = await getServerSession();
    if (!session) {
      return json({ ok: false, code: "SYNC_RELAY_AUTH_REQUIRED" }, 401);
    }
    try {
      const parsed = parseCloudRelayIssueTokenRequest(body);
      const { token, access } = mintCloudRelayToken(
        session.userId,
        parsed.deviceId,
      );
      await registerCloudRelayDevice(access.vaultHash, access.deviceId);
      return json({
        ok: true,
        token,
        expiresAt: new Date(access.expiresAt).toISOString(),
        channels: {
          rest: "/api/sync-relay",
          websocket: "/api/sync-relay/ws",
        },
      });
    } catch {
      return json({ ok: false, code: "INVALID_RELAY_TOKEN_REQUEST" }, 400);
    }
  }

  const access = relayAccess(request);
  if (!access) {
    return json({ ok: false, code: "SYNC_RELAY_TOKEN_REQUIRED" }, 401);
  }
  try {
    const parsed = parseCloudRelayPushRequest(body);
    if (
      parsed.envelopes.some((envelope) => envelope.deviceId !== access.deviceId)
    ) {
      return json({ ok: false, code: "RELAY_DEVICE_MISMATCH" }, 403);
    }
    await pushCloudRelayEnvelopes(
      access.vaultHash,
      access.deviceId,
      parsed.envelopes,
    );
    return json({ ok: true, accepted: parsed.envelopes.length }, 202);
  } catch (error) {
    const capacity =
      error instanceof Error && error.message.includes("capacity");
    return json(
      {
        ok: false,
        code: capacity
          ? "SYNC_RELAY_CAPACITY_EXCEEDED"
          : "INVALID_ENCRYPTED_ENVELOPE",
      },
      capacity ? 413 : 400,
    );
  }
}

export async function GET(request: Request) {
  const access = relayAccess(request);
  if (!access) {
    return json({ ok: false, code: "SYNC_RELAY_TOKEN_REQUIRED" }, 401);
  }
  const envelopes = await takeCloudRelayEnvelopes(
    access.vaultHash,
    access.deviceId,
  );
  const devices = await listCloudRelayDevices(access.vaultHash);
  return json({
    ok: true,
    envelopes,
    devices,
    retention: {
      encryptedOnly: true,
      maximumDays: 30,
      consumedAfterDeviceRetrieval: true,
    },
  });
}

export async function DELETE(request: Request) {
  const access = relayAccess(request);
  if (!access) {
    return json({ ok: false, code: "SYNC_RELAY_TOKEN_REQUIRED" }, 401);
  }
  const revokedDeviceId = new URL(request.url).searchParams.get("deviceId");
  if (
    !revokedDeviceId ||
    !DEVICE_ID.test(revokedDeviceId) ||
    revokedDeviceId === access.deviceId
  ) {
    return json({ ok: false, code: "INVALID_REVOKED_DEVICE" }, 400);
  }
  await revokeCloudRelayDevice(access.vaultHash, revokedDeviceId);
  return json({ ok: true });
}

export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      ...cloudRelaySecurityHeaders(),
      Allow: "GET, POST, DELETE, OPTIONS",
    },
  });
}

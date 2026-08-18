import { NextResponse } from "next/server";

import {
  buildCaptureCookie,
  isValidDeviceId,
  signCaptureToken,
  verifyCaptureToken,
} from "@/lib/server/capture-auth-crypto";
import { guardAttestRoute } from "@/lib/server/api-guard";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import { registerCaptureAttestation } from "@/lib/server/capture-attest-store";
import {
  ipHashFromRequest,
  userAgentHashFromRequest,
} from "@/lib/server/request-identity";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

/** Issue a signed capture cookie for this browser device (local-first, no account). */
export async function POST(request: Request) {
  const attestGuard = await guardAttestRoute(request);
  if (!attestGuard.ok) return attestGuard.response;

  const session = await getServerSession();
  if (session) {
    return NextResponse.json({
      ok: true,
      via: "session",
      userId: session.userId,
    });
  }

  let deviceId: string | undefined;
  try {
    const body = (await request.json()) as { deviceId?: string };
    deviceId = body.deviceId?.trim();
  } catch {
    deviceId = undefined;
  }

  if (!deviceId || !isValidDeviceId(deviceId)) {
    return apiErrorResponse({ code: "INVALID_DEVICE", route: "capture/attest" });
  }

  const binding = {
    ipHash: ipHashFromRequest(request),
    uaHash: userAgentHashFromRequest(request),
  };

  const token = signCaptureToken(deviceId, binding);
  const payload = verifyCaptureToken(token, binding);
  if (!payload) {
    return apiErrorResponse({
      code: "ATTEST_FAILED",
      route: "capture/attest",
      logEvent: "api_error",
    });
  }

  await registerCaptureAttestation({
    jti: payload.jti,
    deviceId: payload.deviceId,
    ipHash: binding.ipHash,
    uaHash: binding.uaHash,
  });

  const response = NextResponse.json({
    ok: true,
    via: "capture",
    deviceId,
    token,
    expiresInSeconds: Math.floor(
      (payload.exp - Date.now()) / 1000,
    ),
  });
  response.cookies.set(buildCaptureCookie(token));
  return response;
}

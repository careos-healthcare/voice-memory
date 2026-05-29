import "server-only";

import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import {
  CAPTURE_COOKIE,
  verifyCaptureToken,
} from "@/lib/server/capture-auth-crypto";
import { consumeCaptureAttestation } from "@/lib/server/capture-attest-store";
import {
  checkAndRecordApiUsage,
  type ApiUsageKind,
} from "@/lib/server/api-usage-store";
import {
  ipHashFromRequest,
  userAgentHashFromRequest,
} from "@/lib/server/request-identity";
import { getServerSession } from "@/lib/server/session";

export const MAX_AUDIO_BYTES = 12 * 1024 * 1024;
export const MAX_TRANSCRIPT_CHARS = 24_000;
export const MAX_ATMOSPHERE_PROMPT_CHARS = 2_000;

export interface ApiGuardContext {
  subject: string;
  via: "session" | "capture";
  userId?: string;
  deviceId?: string;
}

function bindingFromRequest(request: Request): { ipHash: string; uaHash: string } {
  return {
    ipHash: ipHashFromRequest(request),
    uaHash: userAgentHashFromRequest(request),
  };
}

async function verifyCaptureFromRequest(
  request: Request,
  token: string,
): Promise<ApiGuardContext | null> {
  const binding = bindingFromRequest(request);
  const payload = verifyCaptureToken(token, binding);
  if (!payload) return null;

  const consumed = await consumeCaptureAttestation(payload.jti, binding);
  if (!consumed.ok) return null;

  return {
    subject: `device:${payload.deviceId}`,
    via: "capture",
    deviceId: payload.deviceId,
  };
}

export async function resolveApiGuardContext(
  request: Request,
): Promise<ApiGuardContext | null> {
  const session = await getServerSession();
  if (session) {
    return {
      subject: `user:${session.userId}`,
      via: "session",
      userId: session.userId,
    };
  }

  const cookieStore = await cookies();
  const captureToken = cookieStore.get(CAPTURE_COOKIE)?.value;
  if (captureToken) {
    const ctx = await verifyCaptureFromRequest(request, captureToken);
    if (ctx) return ctx;
  }

  const headerToken = request.headers.get("x-vm-capture-token");
  if (headerToken) {
    return verifyCaptureFromRequest(request, headerToken);
  }

  return null;
}

export function apiUnauthorized(
  code: string,
  message: string,
): NextResponse {
  return NextResponse.json({ error: message, code }, { status: 401 });
}

export function apiRateLimited(
  code: string,
  message: string,
  extra?: Record<string, number>,
): NextResponse {
  return NextResponse.json({ error: message, code, ...extra }, { status: 429 });
}

export function apiPayloadTooLarge(message: string): NextResponse {
  return NextResponse.json({ error: message, code: "PAYLOAD_TOO_LARGE" }, { status: 413 });
}

export async function guardOpenAiRoute(
  request: Request,
  kind: ApiUsageKind,
): Promise<{ ok: true; ctx: ApiGuardContext } | { ok: false; response: NextResponse }> {
  const ctx = await resolveApiGuardContext(request);
  if (!ctx) {
    return {
      ok: false,
      response: apiUnauthorized(
        "CAPTURE_AUTH_REQUIRED",
        "Sign in or attest this device before using voice analysis.",
      ),
    };
  }

  const ipSubject = `ip:${ipHashFromRequest(request)}`;
  const usageSubject = ctx.subject;
  const usage = await checkAndRecordApiUsage(usageSubject, kind);
  if (!usage.allowed) {
    return rateLimitResponse(usage);
  }

  const ipUsage = await checkAndRecordApiUsage(ipSubject, kind);
  if (!ipUsage.allowed) {
    return rateLimitResponse(ipUsage);
  }

  return { ok: true, ctx };
}

function rateLimitResponse(usage: {
  reason?: "minute_burst" | "daily_cap";
  dailyCount?: number;
  dailyLimit?: number;
}): { ok: false; response: NextResponse } {
  if (usage.reason === "minute_burst") {
    return {
      ok: false,
      response: apiRateLimited(
        "RATE_LIMIT_MINUTE",
        "Too many requests. Wait a minute and try again.",
      ),
    };
  }
  return {
    ok: false,
    response: apiRateLimited(
      "RATE_LIMIT_DAILY",
      "Daily limit reached. Try again tomorrow.",
      {
        dailyCount: usage.dailyCount ?? 0,
        dailyLimit: usage.dailyLimit ?? 0,
      },
    ),
  };
}

export async function guardAttestRoute(
  request: Request,
): Promise<{ ok: true } | { ok: false; response: NextResponse }> {
  const ipSubject = `ip:${ipHashFromRequest(request)}`;
  const usage = await checkAndRecordApiUsage(ipSubject, "attest");
  if (!usage.allowed) {
    return rateLimitResponse(usage);
  }
  return { ok: true };
}

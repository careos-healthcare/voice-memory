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
  guardOpenAiBudget,
  isOpenAiKillSwitchActive,
  openAiKillSwitchResponse,
} from "@/lib/server/openai-budget-guard";
import {
  ipHashFromRequest,
  userAgentHashFromRequest,
} from "@/lib/server/request-identity";
import { getServerSession } from "@/lib/server/session";
import {
  capabilityForExpensiveRoute,
  requireMonetizedAccess,
  type MonetizedAccessContext,
} from "@/lib/server/monetized-access-guard";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export {
  MAX_AUDIO_BYTES,
  MAX_ATMOSPHERE_PROMPT_CHARS,
  MAX_TRANSCRIPT_CHARS,
} from "@/lib/server/api-limits";

export interface ApiGuardContext {
  subject: string;
  via: "session" | "capture";
  userId?: string;
  deviceId?: string;
  monetization?: MonetizedAccessContext;
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
    const ctx = await verifyCaptureFromRequest(request, headerToken);
    if (ctx) return ctx;
  }

  const bearerToken = readBearerCaptureToken(request);
  if (bearerToken) {
    return verifyCaptureFromRequest(request, bearerToken);
  }

  return null;
}

export function readBearerCaptureToken(request: Request): string | null {
  const authorization = request.headers.get("authorization")?.trim();
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  const token = authorization.slice("bearer ".length).trim();
  return token || null;
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

export async function resolveCaptureAuthFailureCode(
  request: Request,
): Promise<"missing_capture_token" | "unauthorized_capture_token"> {
  const session = await getServerSession();
  if (session) {
    return "unauthorized_capture_token";
  }

  const headerToken = request.headers.get("x-vm-capture-token")?.trim();
  const cookieStore = await cookies();
  const cookieToken = cookieStore.get(CAPTURE_COOKIE)?.value?.trim();

  if (!headerToken && !cookieToken) {
    return "missing_capture_token";
  }

  return "unauthorized_capture_token";
}

function openAiGuardFailureResponse(
  kind: ApiUsageKind,
  reason: string,
): NextResponse {
  const codes: Record<ApiUsageKind, string> = {
    transcribe: "TRANSCRIBE_UNAVAILABLE",
    analyze: "ANALYZE_UNAVAILABLE",
    atmosphere: "ATMOSPHERE_UNAVAILABLE",
    attest: "ATTEST_UNAVAILABLE",
  };
  console.error(
    `ARCHIVEME_OPENAI_GUARD_FAILED kind=${kind} reason=${reason}`,
  );
  return NextResponse.json(
    {
      error: "Voice processing is temporarily unavailable. Please try again later.",
      code: codes[kind],
    },
    { status: 503 },
  );
}

export async function guardOpenAiRoute(
  request: Request,
  kind: ApiUsageKind,
  options?: {
    transcriptChars?: number;
    durationSeconds?: number;
    audioBytes?: number;
  },
): Promise<{ ok: true; ctx: ApiGuardContext } | { ok: false; response: NextResponse }> {
  let monetizationReservationId: string | undefined;
  try {
    if (isOpenAiKillSwitchActive()) {
      return { ok: false, response: openAiKillSwitchResponse() };
    }

    const ctx = await resolveApiGuardContext(request);
    if (!ctx) {
      const code = await resolveCaptureAuthFailureCode(request);
      const message =
        code === "missing_capture_token"
          ? "Capture token is required before using voice analysis."
          : "Sign in or attest this device before using voice analysis.";
      return {
        ok: false,
        response: NextResponse.json({ error: message, code }, { status: 401 }),
      };
    }

    const monetized = await requireMonetizedAccess({
      userId: ctx.userId,
      capabilityId: capabilityForExpensiveRoute(request),
      idempotencyKey: request.headers.get("x-vm-idempotency-key"),
      requestedUnits:
        kind === "transcribe" && options?.durationSeconds
          ? Math.max(1, Math.ceil(options.durationSeconds))
          : 1,
    });
    if (!monetized.ok) return monetized;
    ctx.monetization = monetized.ctx;
    monetizationReservationId =
      monetized.ctx.reservation?.reservationId;

    const ipSubject = `ip:${ipHashFromRequest(request)}`;
    const usageSubject = ctx.subject;
    const usage = await checkAndRecordApiUsage(usageSubject, kind);
    if (!usage.allowed) {
      if (monetizationReservationId) {
        await releaseUsageReservation(monetizationReservationId);
      }
      return rateLimitResponse(usage);
    }

    const ipUsage = await checkAndRecordApiUsage(ipSubject, kind);
    if (!ipUsage.allowed) {
      if (monetizationReservationId) {
        await releaseUsageReservation(monetizationReservationId);
      }
      return rateLimitResponse(ipUsage);
    }

    const budget = await guardOpenAiBudget(ctx, request, kind, options);
    if (!budget.ok) {
      if (monetizationReservationId) {
        await releaseUsageReservation(monetizationReservationId);
      }
      return budget;
    }

    return { ok: true, ctx };
  } catch (error) {
    if (monetizationReservationId) {
      await releaseUsageReservation(monetizationReservationId).catch(() => {});
    }
    const message = error instanceof Error ? error.message : String(error);
    const lower = message.toLowerCase();
    const reason =
      lower.includes("database") || lower.includes("postgres")
        ? "database_unavailable"
        : lower.includes("auth_secret")
          ? "auth_secret_unconfigured"
          : "guard_exception";
    return {
      ok: false,
      response: openAiGuardFailureResponse(kind, reason),
    };
  }
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

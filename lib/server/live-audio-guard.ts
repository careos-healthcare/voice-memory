import "server-only";

import { NextResponse } from "next/server";

import {
  apiRateLimited,
  apiUnauthorized,
  resolveApiGuardContext,
  resolveCaptureAuthFailureCode,
} from "@/lib/server/api-guard";
import { checkAndRecordLiveAudioUsage } from "@/lib/live-audio/usage-limits";
import { isGeminiConfigured, isGeminiKillSwitchActive } from "@/lib/gemini";
import { ipHashFromRequest } from "@/lib/server/request-identity";
import { requireMonetizedAccess } from "@/lib/server/monetized-access-guard";
import type { ApiGuardContext } from "@/lib/server/api-guard";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export { resetLiveAudioUsageForTest } from "@/lib/live-audio/usage-limits";

export function geminiKillSwitchResponse(): NextResponse {
  return NextResponse.json(
    {
      error: "Live voice is temporarily unavailable. Please try again later.",
      code: "GEMINI_DISABLED",
    },
    { status: 429 },
  );
}

export function geminiNotConfiguredResponse(): NextResponse {
  return NextResponse.json(
    {
      error: "Live voice is not configured on this server.",
      code: "GEMINI_NOT_CONFIGURED",
    },
    { status: 503 },
  );
}

export async function guardLiveAudioSessionRoute(
  request: Request,
): Promise<
  | { ok: true; ctx: ApiGuardContext }
  | { ok: false; response: NextResponse }
> {
  if (isGeminiKillSwitchActive()) {
    return { ok: false, response: geminiKillSwitchResponse() };
  }

  if (!isGeminiConfigured()) {
    return { ok: false, response: geminiNotConfiguredResponse() };
  }

  const ctx = await resolveApiGuardContext(request);
  if (!ctx) {
    const code = await resolveCaptureAuthFailureCode(request);
    const message =
      code === "missing_capture_token"
        ? "Capture token is required before opening a live audio session."
        : "Sign in or attest this device before opening a live audio session.";
    return { ok: false, response: apiUnauthorized(code, message) };
  }

  const monetized = await requireMonetizedAccess({
    userId: ctx.userId,
    capabilityId: "ongoingComparisons",
    idempotencyKey: request.headers.get("x-vm-idempotency-key"),
    requestedUnits: 1,
  });
  if (!monetized.ok) return monetized;
  ctx.monetization = monetized.ctx;
  const reservationId = monetized.ctx.reservation?.reservationId;

  let usage: ReturnType<typeof checkAndRecordLiveAudioUsage>;
  try {
    usage = checkAndRecordLiveAudioUsage(ctx.subject);
  } catch (error) {
    if (reservationId) await releaseUsageReservation(reservationId);
    throw error;
  }
  if (!usage.allowed) {
    if (reservationId) await releaseUsageReservation(reservationId);
    return {
      ok: false,
      response:
        usage.reason === "minute_burst"
          ? apiRateLimited(
              "RATE_LIMIT_MINUTE",
              "Too many live session requests. Wait a minute and try again.",
            )
          : apiRateLimited(
              "RATE_LIMIT_DAILY",
              "Daily live session limit reached. Try again tomorrow.",
              {
                dailyCount: usage.dailyCount ?? 0,
                dailyLimit: usage.dailyLimit ?? 0,
              },
            ),
    };
  }

  let ipUsage: ReturnType<typeof checkAndRecordLiveAudioUsage>;
  try {
    ipUsage = checkAndRecordLiveAudioUsage(`ip:${ipHashFromRequest(request)}`);
  } catch (error) {
    if (reservationId) await releaseUsageReservation(reservationId);
    throw error;
  }
  if (!ipUsage.allowed) {
    if (reservationId) await releaseUsageReservation(reservationId);
    return {
      ok: false,
      response:
        ipUsage.reason === "minute_burst"
          ? apiRateLimited(
              "RATE_LIMIT_MINUTE",
              "Too many live session requests. Wait a minute and try again.",
            )
          : apiRateLimited(
              "RATE_LIMIT_DAILY",
              "Daily live session limit reached. Try again tomorrow.",
              {
                dailyCount: ipUsage.dailyCount ?? 0,
                dailyLimit: ipUsage.dailyLimit ?? 0,
              },
            ),
    };
  }

  return { ok: true, ctx };
}

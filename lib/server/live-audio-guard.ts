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
  | { ok: true; ctx: { subject: string; via: "session" | "capture"; userId?: string; deviceId?: string } }
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

  const usage = checkAndRecordLiveAudioUsage(ctx.subject);
  if (!usage.allowed) {
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

  const ipUsage = checkAndRecordLiveAudioUsage(`ip:${ipHashFromRequest(request)}`);
  if (!ipUsage.allowed) {
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

import "server-only";

import { NextResponse } from "next/server";

import type { ApiGuardContext } from "@/lib/server/api-guard";
import type { ApiUsageKind } from "@/lib/server/api-usage-store";
import {
  ANALYZE_UNAVAILABLE_MESSAGE,
  classifyAnalyzeRouteError,
} from "@/lib/analyze/analyze-route-failure";
import {
  estimateOpenAiBudgetCharge,
  getOpenAiBudgetLimits,
  isOpenAiKillSwitchActive,
  logOpenAiBudgetDenial,
  reserveOpenAiBudget,
  type OpenAiBudgetScope,
} from "@/lib/server/openai-budget-core";
import { ipHashFromRequest } from "@/lib/server/request-identity";

export type { OpenAiBudgetCheckResult, OpenAiBudgetScope } from "@/lib/server/openai-budget-core";
export { getOpenAiBudgetLimits, isOpenAiKillSwitchActive } from "@/lib/server/openai-budget-core";

export function openAiBudgetExceededResponse(
  scope?: OpenAiBudgetScope,
): NextResponse {
  const code =
    scope === "global" || scope === "route"
      ? "OPENAI_PLATFORM_LIMIT"
      : "OPENAI_BUDGET_EXCEEDED";
  return NextResponse.json(
    {
      error: "Voice processing is temporarily limited. Please try again later.",
      code,
    },
    { status: 429 },
  );
}

export function openAiKillSwitchResponse(): NextResponse {
  return NextResponse.json(
    {
      error: "Voice processing is temporarily unavailable. Please try again later.",
      code: "OPENAI_DISABLED",
    },
    { status: 429 },
  );
}

export async function guardOpenAiBudget(
  ctx: ApiGuardContext,
  request: Request,
  kind: ApiUsageKind,
  options?: {
    transcriptChars?: number;
    durationSeconds?: number;
    audioBytes?: number;
  },
): Promise<{ ok: true } | { ok: false; response: NextResponse }> {
  if (isOpenAiKillSwitchActive()) {
    return { ok: false, response: openAiKillSwitchResponse() };
  }

  const estimate = estimateOpenAiBudgetCharge(kind, options);
  const check = await reserveOpenAiBudget(ctx, ipHashFromRequest(request), kind, estimate);
  if (!check.allowed) {
    logOpenAiBudgetDenial(check.scope, kind, check.spentMicro, check.limitMicro);
    return { ok: false, response: openAiBudgetExceededResponse(check.scope) };
  }
  return { ok: true };
}

/** Safe client-facing error — never leak OpenAI SDK messages in production. */
export function safeOpenAiRouteError(
  kind: ApiUsageKind,
  error: unknown,
): { message: string; code: string } {
  const codes: Record<ApiUsageKind, string> = {
    transcribe: "TRANSCRIBE_UNAVAILABLE",
    analyze: "ANALYZE_UNAVAILABLE",
    atmosphere: "ATMOSPHERE_UNAVAILABLE",
    attest: "ATTEST_UNAVAILABLE",
  };

  if (kind === "analyze") {
    const classified = classifyAnalyzeRouteError(error);
    if (process.env.NODE_ENV !== "production") {
      return { code: classified.code, message: classified.message };
    }
    if (classified.code === "missing_openai_key") {
      return { code: classified.code, message: classified.message };
    }
    return {
      code: "ANALYZE_UNAVAILABLE",
      message: ANALYZE_UNAVAILABLE_MESSAGE,
    };
  }

  if (!process.env.OPENAI_API_KEY?.trim()) {
    return {
      code: "missing_openai_key",
      message: "Voice processing is not configured on the server.",
    };
  }

  if (process.env.NODE_ENV === "production") {
    return {
      code: codes[kind],
      message: ANALYZE_UNAVAILABLE_MESSAGE,
    };
  }
  const message = error instanceof Error ? error.message : `${kind} failed`;
  return { code: codes[kind], message };
}

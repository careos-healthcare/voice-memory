import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";

import { isGeminiConfigured } from "@/lib/gemini";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import {
  generateThenVsNowComparison,
  ThenVsNowComparisonBlockedError,
} from "@/src/services/insights/comparison";

export const runtime = "nodejs";

function parseIsoDate(value: string | null, label: string): Date | null {
  if (!value?.trim()) return null;
  const parsed = Date.parse(value.trim());
  if (!Number.isFinite(parsed)) {
    throw new Error(`${label} must be a valid ISO-8601 timestamp.`);
  }
  return new Date(parsed);
}

export async function GET(request: Request) {
  try {
    if (!isGeminiConfigured()) {
      return apiErrorResponse({ code: "GEMINI_NOT_CONFIGURED", route: "insights/comparison" });
    }

    if (!process.env.OPENAI_API_KEY?.trim()) {
      return apiErrorResponse({ code: "OPENAI_NOT_CONFIGURED", route: "insights/comparison" });
    }

    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "insights/comparison",
      });
    }

    const url = new URL(request.url);
    const rangeAFrom = parseIsoDate(url.searchParams.get("rangeAFrom"), "rangeAFrom");
    const rangeATo = parseIsoDate(url.searchParams.get("rangeATo"), "rangeATo");
    const rangeBFrom = parseIsoDate(url.searchParams.get("rangeBFrom"), "rangeBFrom");
    const rangeBTo = parseIsoDate(url.searchParams.get("rangeBTo"), "rangeBTo");

    if (!rangeAFrom || !rangeATo || !rangeBFrom || !rangeBTo) {
      return apiErrorResponse({ code: "INVALID_REQUEST", route: "insights/comparison" });
    }

    const comparison = await generateThenVsNowComparison(session.userId, {
      from: rangeAFrom,
      to: rangeATo,
    }, {
      from: rangeBFrom,
      to: rangeBTo,
    });

    return NextResponse.json({
      ok: true,
      comparison: {
        id: randomUUID(),
        evolutionText: comparison.evolutionText,
        confidenceLabel: comparison.confidenceLabel,
        whatRepeated: comparison.whatRepeated,
        whatChanged: comparison.whatChanged,
        thinEvidencePhrase: comparison.thinEvidencePhrase,
        citedEntryIds: comparison.citedEntryIds,
        periodA: {
          from: comparison.periodA.from,
          to: comparison.periodA.to,
          totalEntryCount: comparison.periodA.totalEntryCount,
          usableEntryCount: comparison.periodA.usableEntryCount,
        },
        periodB: {
          from: comparison.periodB.from,
          to: comparison.periodB.to,
          totalEntryCount: comparison.periodB.totalEntryCount,
          usableEntryCount: comparison.periodB.usableEntryCount,
        },
      },
    });
  } catch (error) {
    if (error instanceof ThenVsNowComparisonBlockedError) {
      return apiErrorResponse({
        code: error.code,
        status: 422,
        route: "insights/comparison",
      });
    }

    if (error instanceof Error && error.message.includes("must be a valid ISO")) {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "insights/comparison",
        internalCategory: "validation",
      });
    }

    console.error("insights/comparison failed", error);
    return apiErrorFromException(error, {
      code: "COMPARISON_GENERATION_FAILED",
      route: "insights/comparison",
      logEvent: "api_error",
    });
  }
}

import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";

import { isGeminiConfigured } from "@/lib/gemini";
import {
  apiErrorFromException,
  apiErrorResponse,
  buildApiErrorEnvelope,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import {
  generateWeeklyStory,
  resolveWeeklyStoryWindow,
} from "@/src/services/insights/weekly_story";

export const runtime = "nodejs";

function parseWeekEnding(value: string | null): Date | undefined {
  if (!value?.trim()) return undefined;
  const parsed = Date.parse(value.trim());
  if (!Number.isFinite(parsed)) {
    throw new Error("weekEnding must be a valid ISO-8601 timestamp.");
  }
  return new Date(parsed);
}

export async function GET(request: Request) {
  try {
    if (!isGeminiConfigured()) {
      return apiErrorResponse({ code: "GEMINI_NOT_CONFIGURED", route: "insights/weekly-story" });
    }

    if (!process.env.OPENAI_API_KEY?.trim()) {
      return apiErrorResponse({ code: "OPENAI_NOT_CONFIGURED", route: "insights/weekly-story" });
    }

    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "insights/weekly-story",
      });
    }

    const url = new URL(request.url);
    const weekEnding = parseWeekEnding(url.searchParams.get("weekEnding"));
    const window = resolveWeeklyStoryWindow(weekEnding);

    const outcome = await generateWeeklyStory(session.userId, window);

    if (outcome.blocked) {
      const built = buildApiErrorEnvelope({
        code: "INSUFFICIENT_EVIDENCE",
        status: 422,
      });
      return NextResponse.json(
        {
          ok: false,
          blocked: true,
          ...built.body,
          weekStart: outcome.weekStart,
          weekEnd: outcome.weekEnd,
          entryCountThisWeek: outcome.entryCountThisWeek,
          usableEntryCountThisWeek: outcome.usableEntryCountThisWeek,
          strongEntryCountTotal: outcome.strongEntryCountTotal,
        },
        { status: 422 },
      );
    }

    return NextResponse.json({
      ok: true,
      story: {
        id: randomUUID(),
        storyText: outcome.storyText,
        confidenceBand: outcome.confidenceBand,
        citedEntryIds: outcome.citedEntryIds,
        weekStart: outcome.weekStart,
        weekEnd: outcome.weekEnd,
        entryCountThisWeek: outcome.entryCountThisWeek,
        usableEntryCountThisWeek: outcome.usableEntryCountThisWeek,
      },
    });
  } catch (error) {
    if (error instanceof Error && error.message.includes("weekEnding must be")) {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "insights/weekly-story",
        internalCategory: "validation",
      });
    }

    console.error("insights/weekly-story failed", error);
    return apiErrorFromException(error, {
      code: "WEEKLY_STORY_GENERATION_FAILED",
      route: "insights/weekly-story",
      logEvent: "api_error",
    });
  }
}

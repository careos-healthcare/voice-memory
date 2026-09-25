import { NextResponse } from "next/server";

import { guardOpenAiRoute } from "@/lib/server/api-guard";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { getOpenAIClient } from "@/lib/openai";
import type { WeeklyReflectionPayload } from "@/types/weekly";
import {
  sanitizeWeeklyAggregate,
  sanitizeWeeklyEntries,
  synthesizeWeeklyRecap,
  weeklyInputError,
} from "../../../src/routes/weekly-reflection";

export const runtime = "nodejs";

const SYSTEM_PROMPT = `You detect weekly language patterns for ArchiveMe — ${PRODUCT_WEDGE_LINE} NOT therapy.
Given aggregated statistics from a user's last 7 days of voice reflections (no raw transcripts), write ONE paragraph (4-6 sentences) of pattern observations.

Rules:
- Speak directly to the user ("you")
- Use observation language: "You repeatedly…", "You tend to…", "You describe X differently…"
- Reference dominant emotions, themes, concerns, and week-over-week shift when provided
- Be specific but never clinical; do not diagnose
- NO advice, NO "you should", NO motivational encouragement, NO intentions for next week
- Never mention being an AI
- Return JSON only: { "summary": "..." }`;

function parseSummary(raw: string): string {
  const parsed = JSON.parse(raw) as { summary?: string };
  if (typeof parsed.summary !== "string" || !parsed.summary.trim()) {
    throw new Error("Invalid weekly summary structure");
  }
  return parsed.summary.trim();
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as WeeklyReflectionPayload & {
      entries?: unknown;
      transcripts?: unknown;
    };

    const inputError = weeklyInputError(body);
    if (inputError) {
      return apiErrorResponse({
        code: "WEEKLY_REFLECTION_NO_ENTRIES",
        message: inputError,
        status: 400,
        route: "weekly-reflection",
      });
    }

    if (Array.isArray(body.entries)) {
      const entries = sanitizeWeeklyEntries(body.entries);
      if (!entries) {
        return apiErrorResponse({
          code: "WEEKLY_REFLECTION_NO_ENTRIES",
          message: "Each entry needs an id, text, and timestamp.",
          status: 400,
          route: "weekly-reflection",
        });
      }
      const recap = await synthesizeWeeklyRecap(entries);
      return NextResponse.json(recap);
    }

    const aggregate = sanitizeWeeklyAggregate(body as Record<string, unknown>);
    if (typeof aggregate === "string") {
      return apiErrorResponse({
        code: "WEEKLY_REFLECTION_NO_ENTRIES",
        message: aggregate,
        status: 400,
        route: "weekly-reflection",
      });
    }
    if (aggregate.entryCount === 0) {
      return apiErrorResponse({ code: "WEEKLY_REFLECTION_NO_ENTRIES", route: "weekly-reflection" });
    }

    const guard = await guardOpenAiRoute(request, "analyze");
    if (!guard.ok) return guard.response;

    const openai = getOpenAIClient();

    const userContent = `Weekly intelligence aggregates (last 7 days vs prior 7 days):

This week (${aggregate.weekEndingKey} window):
- Entries: ${aggregate.entryCount}
- Dominant emotions: ${aggregate.dominantEmotions.join(", ") || "none"}
- Recurring themes: ${aggregate.recurringThemes.join(", ") || "none"}
- Repeated threads: ${aggregate.repeatedConcerns.join("; ") || "none"}
- People/entities mentioned: ${aggregate.repeatedEntities.join(", ") || "none"}
- Average emotional intensity: ${aggregate.avgIntensityThisWeek ?? "n/a"}/10
- Emotional shift vs last week: ${aggregate.emotionalShiftLabel}
- Pattern observations: ${aggregate.observationHighlights.join(" | ") || "none"}

Last week:
- Entries: ${aggregate.lastWeekEntryCount}
- Average intensity: ${aggregate.avgIntensityLastWeek ?? "n/a"}/10

Write the weekly pattern observation summary.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      temperature: 0.75,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userContent },
      ],
    });

    const content = completion.choices[0]?.message?.content;
    if (!content) {
      return apiErrorResponse({ code: "WEEKLY_REFLECTION_NO_SUMMARY", route: "weekly-reflection" });
    }

    const summary = parseSummary(content);
    return NextResponse.json({ summary });
  } catch (error) {
    console.error("Weekly reflection failed:", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return apiErrorResponse({
      code: safe.code,
      message: safe.message,
      status: 500,
      logEvent: "api_error",
      internalCategory: "internal_error",
      route: "weekly-reflection",
    });
  }
}

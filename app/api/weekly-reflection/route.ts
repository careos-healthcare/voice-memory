import { NextResponse } from "next/server";

import { PRODUCT_WEDGE_LINE } from "@/lib/product-copy";
import { getOpenAIClient } from "@/lib/openai";
import type { WeeklyReflectionPayload } from "@/types/weekly";

export const runtime = "nodejs";

const SYSTEM_PROMPT = `You detect weekly language patterns for VoiceMemory — ${PRODUCT_WEDGE_LINE} NOT therapy.
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
    const body = (await request.json()) as WeeklyReflectionPayload;

    if (!body.weekEndingKey || body.entryCount === 0) {
      return NextResponse.json(
        { error: "No entries in the current week window" },
        { status: 400 },
      );
    }

    const openai = getOpenAIClient();

    const userContent = `Weekly intelligence aggregates (last 7 days vs prior 7 days):

This week (${body.weekEndingKey} window):
- Entries: ${body.entryCount}
- Dominant emotions: ${body.dominantEmotions.join(", ") || "none"}
- Recurring themes: ${body.recurringThemes.join(", ") || "none"}
- Repeated threads: ${body.repeatedConcerns.join("; ") || "none"}
- People/entities mentioned: ${body.repeatedEntities.join(", ") || "none"}
- Average emotional intensity: ${body.avgIntensityThisWeek ?? "n/a"}/10
- Emotional shift vs last week: ${body.emotionalShiftLabel}
- Pattern observations: ${body.observationHighlights.join(" | ") || "none"}

Last week:
- Entries: ${body.lastWeekEntryCount}
- Average intensity: ${body.avgIntensityLastWeek ?? "n/a"}/10

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
      return NextResponse.json(
        { error: "No summary returned from model" },
        { status: 502 },
      );
    }

    const summary = parseSummary(content);
    return NextResponse.json({ summary });
  } catch (error) {
    console.error("Weekly reflection failed:", error);
    const message =
      error instanceof Error ? error.message : "Weekly reflection failed";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

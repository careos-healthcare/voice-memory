import { NextResponse } from "next/server";

import { getOpenAIClient } from "@/lib/openai";
import type { Reflection } from "@/types/journal";

export const runtime = "nodejs";

const SYSTEM_PROMPT = `You are an emotionally intelligent journal companion for VoiceMemory.
Given a spoken journal transcript, return a JSON object with exactly these keys:
- mood: a concise emotional label (2-4 words)
- emotionalIntensity: integer from 1 to 10
- recurringThemes: array of 2-4 short theme strings
- hiddenConcern: one sentence about an underlying worry they may not have named directly
- positiveSignal: one sentence about a strength, hope, or healthy signal in what they shared
- recommendation: one gentle, actionable recommendation for the next 24 hours

Be warm, precise, and non-clinical. Never diagnose. Never mention being an AI.
Respond with valid JSON only.`;

function parseReflection(raw: string): Reflection {
  const parsed = JSON.parse(raw) as Partial<Reflection>;

  const intensity = Number(parsed.emotionalIntensity);
  const themes = Array.isArray(parsed.recurringThemes)
    ? parsed.recurringThemes.filter((theme): theme is string => typeof theme === "string")
    : [];

  if (
    typeof parsed.mood !== "string" ||
    !Number.isFinite(intensity) ||
    typeof parsed.hiddenConcern !== "string" ||
    typeof parsed.positiveSignal !== "string" ||
    typeof parsed.recommendation !== "string"
  ) {
    throw new Error("Invalid reflection structure from model");
  }

  return {
    mood: parsed.mood.trim(),
    emotionalIntensity: Math.min(10, Math.max(1, Math.round(intensity))),
    recurringThemes: themes.slice(0, 4),
    hiddenConcern: parsed.hiddenConcern.trim(),
    positiveSignal: parsed.positiveSignal.trim(),
    recommendation: parsed.recommendation.trim(),
  };
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { transcript?: string };
    const transcript = body.transcript?.trim();

    if (!transcript) {
      return NextResponse.json(
        { error: "Transcript is required" },
        { status: 400 },
      );
    }

    const openai = getOpenAIClient();
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      temperature: 0.7,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: `Reflect on this voice journal entry:\n\n${transcript}`,
        },
      ],
    });

    const content = completion.choices[0]?.message?.content;

    if (!content) {
      return NextResponse.json(
        { error: "No reflection returned from model" },
        { status: 502 },
      );
    }

    const reflection = parseReflection(content);
    return NextResponse.json({ reflection });
  } catch (error) {
    console.error("Analysis failed:", error);
    const message =
      error instanceof Error ? error.message : "Analysis failed";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

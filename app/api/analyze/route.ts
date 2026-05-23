import { NextResponse } from "next/server";

import { normalizeReflection } from "@/lib/reflection";
import { getOpenAIClient } from "@/lib/openai";
import type { Reflection } from "@/types/journal";

export const runtime = "nodejs";

const BANNED_PHRASES = [
  "deep-seated",
  "deep seated",
  "seeking balance",
  "resilience and commitment",
  "inner journey",
  "hold space",
  "self-care journey",
  "emotional landscape",
  "navigate your feelings",
];

const SYSTEM_PROMPT = `You reflect on voice journal transcripts for VoiceMemory — a private reflective mirror, NOT therapy.

SAFETY (follow strictly):
- This is not therapy, counseling, or medical advice.
- Do not diagnose, label disorders, or claim clinical insight.
- You are a reflective mirror: describe what the person actually said and did emotionally.

STYLE (follow strictly):
- Be concrete and specific to THIS transcript only.
- Quote or closely paraphrase their exact words where possible.
- Name specific topics, people, situations, and actions they mentioned.
- NEVER use vague therapy clichés or filler such as: "deep-seated fear", "you may be seeking balance", "resilience and commitment", "hold space for yourself", "your emotional journey", "inner landscape".
- If the transcript is thin, say what is missing instead of inventing depth.

Return a JSON object with exactly these keys:

Legacy (required, keep concise):
- mood: 2-4 word emotional label grounded in their words
- emotionalIntensity: integer 1-10
- recurringThemes: array of 2-4 short theme strings from the transcript
- hiddenConcern: one sentence — a specific worry implied by what they said (not generic)
- positiveSignal: one sentence — a specific strength or hopeful detail they named
- recommendation: one gentle sentence (legacy field; keep practical)

Specific (required, must cite transcript):
- exactLanguagePattern: a short quote OR tight paraphrase of their distinctive phrasing (max 25 words)
- concreteObservation: one sentence describing what happened in their story — who, what, when, feeling (no vague generalities)
- repeatedSignal: one sentence on a pattern they repeated or emphasized in this entry (or "No clear repeat in this short entry" if true)
- nextSmallAction: one tiny, specific action for the next 24 hours tied to their words (under 20 words)

Respond with valid JSON only. Never mention being an AI.`;

function containsBannedPhrase(text: string): boolean {
  const lower = text.toLowerCase();
  return BANNED_PHRASES.some((phrase) => lower.includes(phrase));
}

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
    typeof parsed.recommendation !== "string" ||
    typeof parsed.exactLanguagePattern !== "string" ||
    typeof parsed.concreteObservation !== "string" ||
    typeof parsed.repeatedSignal !== "string" ||
    typeof parsed.nextSmallAction !== "string"
  ) {
    throw new Error("Invalid reflection structure from model");
  }

  const reflection = normalizeReflection({
    mood: parsed.mood,
    emotionalIntensity: intensity,
    recurringThemes: themes,
    hiddenConcern: parsed.hiddenConcern,
    positiveSignal: parsed.positiveSignal,
    recommendation: parsed.recommendation,
    exactLanguagePattern: parsed.exactLanguagePattern,
    concreteObservation: parsed.concreteObservation,
    repeatedSignal: parsed.repeatedSignal,
    nextSmallAction: parsed.nextSmallAction,
  });

  const textFields = [
    reflection.hiddenConcern,
    reflection.positiveSignal,
    reflection.recommendation,
    reflection.concreteObservation ?? "",
    reflection.repeatedSignal ?? "",
    reflection.nextSmallAction ?? "",
  ];

  if (textFields.some(containsBannedPhrase)) {
    throw new Error("Reflection contained generic therapy language");
  }

  return reflection;
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
      temperature: 0.55,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: `Analyze this voice journal transcript. Ground every field in what they actually said:\n\n${transcript}`,
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

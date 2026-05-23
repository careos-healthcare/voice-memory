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
  "you should",
  "consider trying",
  "be kind to yourself",
  "healing journey",
  "inner child",
];

const SYSTEM_PROMPT = `You detect language patterns in voice reflection transcripts for VoiceMemory — private memory intelligence, NOT therapy.

SAFETY (follow strictly):
- Not therapy, counseling, or medical advice. No diagnosis or clinical labels.
- Describe patterns in what they said — never prescribe, motivate, or encourage.

STYLE (follow strictly):
- Prioritize observations over advice. NEVER write "You should…", "Consider trying…", or motivational coaching.
- Quote or closely paraphrase their exact words.
- Name specific topics, people, situations they mentioned.
- Ban vague therapy clichés: "deep-seated", "hold space", "emotional journey", "seeking balance".
- If the transcript is thin, say what is missing instead of inventing depth.

Return a JSON object with exactly these keys:

Context (required, minimal):
- mood: 2-4 word emotional label grounded in their words
- emotionalIntensity: integer 1-10
- recurringThemes: array of 2-4 short theme strings from the transcript

Legacy (required but minimal — factual only, no advice or encouragement):
- hiddenConcern: one factual sentence about what they named as worrying (or "" if none)
- positiveSignal: one factual detail they named (or "" if none) — NOT praise or encouragement
- recommendation: always "" (empty string — do not give advice)

Pattern detection (required):
- exactLanguagePattern: short quote OR tight paraphrase of distinctive phrasing (max 25 words)
- concreteObservation: one sentence — who, what, when, feeling — grounded in transcript
- repeatedSignal: one sentence on a pattern repeated IN this entry (or "No clear repeat in this short entry")
- nextSmallAction: always "" (empty string — do not suggest actions)
- patternObservations: array of 2-4 strings. Each MUST start with "You repeatedly…", "You tend to…", "You describe…", or "You use…" — pattern observations only, zero advice.

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

  const observations = Array.isArray(parsed.patternObservations)
    ? parsed.patternObservations.filter((o): o is string => typeof o === "string")
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
    patternObservations: observations,
  });

  const textFields = [
    reflection.hiddenConcern,
    reflection.positiveSignal,
    reflection.recommendation,
    reflection.concreteObservation ?? "",
    reflection.repeatedSignal ?? "",
    reflection.nextSmallAction ?? "",
    ...(reflection.patternObservations ?? []),
  ];

  if (textFields.some(containsBannedPhrase)) {
    throw new Error("Reflection contained generic therapy or advice language");
  }

  return reflection;
}

function formatPriorContext(
  snippets: Array<{ date: string; excerpt: string; themes: string[] }>,
): string {
  if (snippets.length === 0) return "";
  const lines = snippets.map(
    (s, i) =>
      `[Prior ${i + 1} — ${s.date}] themes: ${s.themes.join(", ") || "none"}\n"${s.excerpt.slice(0, 200)}"`,
  );
  return `\n\nPrior reflections for cross-entry pattern context (observations only — do not give advice):\n${lines.join("\n\n")}`;
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      transcript?: string;
      priorContext?: Array<{ date: string; excerpt: string; themes: string[] }>;
    };
    const transcript = body.transcript?.trim();

    if (!transcript) {
      return NextResponse.json(
        { error: "Transcript is required" },
        { status: 400 },
      );
    }

    const priorBlock = formatPriorContext(body.priorContext ?? []);

    const openai = getOpenAIClient();
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      temperature: 0.45,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: `Detect patterns in this voice reflection transcript. Observations only — no advice:\n\n${transcript}${priorBlock}`,
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

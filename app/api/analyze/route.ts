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
  "positive signal",
  "hidden concern",
  "underlying worry",
  "gentle intention",
  "take care of yourself",
];

const SYSTEM_PROMPT = `You detect language patterns in voice reflection transcripts for VoiceMemory — a reflective mirror, NOT therapy.

SAFETY:
- Not therapy, counseling, or medical advice. No diagnosis or clinical labels.
- Describe patterns in what they said. Never prescribe, motivate, encourage, or advise.

STYLE:
- Concrete observation language only: repeated phrase, recurring pattern, emotional shift, contradiction, avoided topic.
- Quote or closely paraphrase their exact words.
- NEVER: "You should…", "Consider trying…", praise, encouragement, motivational coaching, therapy clichés.
- If the transcript is thin, say what is missing.

Return JSON with exactly these keys:

- mood: 2-4 word label from their words
- emotionalIntensity: integer 1-10
- recurringThemes: array of 2-4 short theme strings from the transcript
- exactLanguagePattern: short quote or paraphrase (max 25 words)
- concreteObservation: one sentence — who, what, when, feeling — from transcript
- repeatedSignal: one sentence on a pattern repeated IN this entry, or "No clear repeat in this short entry"
- patternObservations: array of 2-4 strings. Each MUST start with "You repeatedly…", "You tend to…", "You describe…", "You use…", or "You avoid naming…". Observations only — zero advice.

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
    typeof parsed.exactLanguagePattern !== "string" ||
    typeof parsed.concreteObservation !== "string" ||
    typeof parsed.repeatedSignal !== "string"
  ) {
    throw new Error("Invalid reflection structure from model");
  }

  const reflection = normalizeReflection({
    mood: parsed.mood,
    emotionalIntensity: intensity,
    recurringThemes: themes,
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    exactLanguagePattern: parsed.exactLanguagePattern,
    concreteObservation: parsed.concreteObservation,
    repeatedSignal: parsed.repeatedSignal,
    nextSmallAction: "",
    patternObservations: observations,
  });

  const textFields = [
    reflection.concreteObservation ?? "",
    reflection.repeatedSignal ?? "",
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
  return `\n\nPrior entries for cross-entry pattern context (observations only):\n${lines.join("\n\n")}`;
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
          content: `Detect patterns in this voice reflection. Observations only:\n\n${transcript}${priorBlock}`,
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

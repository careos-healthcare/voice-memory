import { NextResponse } from "next/server";

import { normalizeReflection } from "@/lib/reflection";
import { buildPatternObservationsFromAnalysis } from "@/lib/observation-language";
import { getOpenAIClient } from "@/lib/openai";
import type { Reflection } from "@/types/journal";

export const runtime = "nodejs";

const BANNED_PHRASES = [
  "deep-seated",
  "deep seated",
  "you may be seeking",
  "you might be seeking",
  "seeking balance",
  "resilience",
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
  "it's okay to feel",
  "remember that you",
  "trust the process",
  "honor your feelings",
  "give yourself permission",
  "self-compassion",
  "processing your emotions",
  "validating your experience",
  "you deserve",
  "proud of you",
  "stay strong",
  "everything happens for a reason",
];

const SYSTEM_PROMPT = `You are VoiceMemory's reflective mirror. You read voice transcripts and return sharp, concrete pattern notes — not therapy, not coaching, not diagnosis.

VOICE:
- Short sentences. No filler. No warmth padding. No AI cheerleading.
- Quote the speaker's words in double quotes whenever possible.
- Name what repeats, pulls in two directions, or stays vague — plainly.
- Slightly sharp is fine; cruelty, clinical labels, and diagnosis are not.
- Observation beats recommendation. If there is no concrete next step in their words, leave it blank.

NEVER USE OR IMPLY:
- Generic encouragement, praise, or motivation
- Therapy-speak ("hold space", "inner journey", "processing", "validate", "resilience")
- "You may be seeking…", "deep-seated", vague advice, or disguised coaching
- "You should…", "Consider trying…", "Be kind to yourself…"
- Diagnosis, disorder names, or clinical labels

OUTPUT — valid JSON only, with these keys in priority order:

1. exactLanguagePattern (string, required): verbatim quote or tight paraphrase, max 20 words — their sharpest recurring phrase.
2. concreteObservation (string, required): one sentence — who, what, when, feeling — grounded in transcript.
3. tensionOrContradiction (string): one sentence on pull-between or reversal IN this entry, or "" if none.
4. repeatedSignal (string, required): one sentence on language repeated IN this entry, or "Nothing repeated clearly in this entry."
5. avoidedOrVagueArea (string): one sentence if they circle something without naming it ("that situation", "stuff", hedging), or "".
6. nextSmallAction (string): concrete next step taken FROM their words only, max 12 words, or "". Not generic advice.

Also include:
- mood: 2-4 word label from their language (not clinical)
- emotionalIntensity: integer 1-10
- recurringThemes: array of 2-4 short theme strings from the transcript

Do NOT include hiddenConcern, positiveSignal, recommendation, or patternObservations.

If the transcript is thin, say what is missing — do not invent depth.

Never mention being an AI.`;

function containsBannedPhrase(text: string): boolean {
  const lower = text.toLowerCase();
  return BANNED_PHRASES.some((phrase) => lower.includes(phrase));
}

function optionalField(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
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
    typeof parsed.exactLanguagePattern !== "string" ||
    typeof parsed.concreteObservation !== "string" ||
    typeof parsed.repeatedSignal !== "string"
  ) {
    throw new Error("Invalid reflection structure from model");
  }

  const base = normalizeReflection({
    mood: parsed.mood,
    emotionalIntensity: intensity,
    recurringThemes: themes,
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    exactLanguagePattern: parsed.exactLanguagePattern,
    concreteObservation: parsed.concreteObservation,
    repeatedSignal: parsed.repeatedSignal,
    tensionOrContradiction: optionalField(parsed.tensionOrContradiction),
    avoidedOrVagueArea: optionalField(parsed.avoidedOrVagueArea),
    nextSmallAction: optionalField(parsed.nextSmallAction),
    patternObservations: buildPatternObservationsFromAnalysis({
      exactLanguagePattern: parsed.exactLanguagePattern,
      concreteObservation: parsed.concreteObservation,
      tensionOrContradiction: optionalField(parsed.tensionOrContradiction),
      repeatedSignal: parsed.repeatedSignal,
      avoidedOrVagueArea: optionalField(parsed.avoidedOrVagueArea),
      nextSmallAction: optionalField(parsed.nextSmallAction),
    }),
  });

  const textFields = [
    base.exactLanguagePattern ?? "",
    base.concreteObservation ?? "",
    base.tensionOrContradiction ?? "",
    base.repeatedSignal ?? "",
    base.avoidedOrVagueArea ?? "",
    base.nextSmallAction ?? "",
    ...(base.patternObservations ?? []),
  ];

  if (textFields.some(containsBannedPhrase)) {
    throw new Error("Reflection contained generic therapy or advice language");
  }

  return base;
}

function formatPriorContext(
  snippets: Array<{ date: string; excerpt: string; themes: string[] }>,
): string {
  if (snippets.length === 0) return "";
  const lines = snippets.map(
    (s, i) =>
      `[Prior ${i + 1} — ${s.date}] themes: ${s.themes.join(", ") || "none"}\n"${s.excerpt.slice(0, 200)}"`,
  );
  return `\n\nPrior entries for cross-entry context (mirror their wording, do not advise):\n${lines.join("\n\n")}`;
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
      temperature: 0.35,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: `Read this voice reflection like a sharp mirror. Quote their words. Observations only:\n\n${transcript}${priorBlock}`,
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

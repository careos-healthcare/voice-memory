import { buildPatternObservationsFromAnalysis } from "@/lib/observation-language";
import { normalizeReflection } from "@/lib/reflection";
import type { Reflection } from "@/types/journal";

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
  "speaker expresses",
  "the speaker expresses",
  "user expresses",
  "the user feels",
  "appears to be feeling",
  "seems to feel",
];

function containsBannedPhrase(text: string): boolean {
  const lower = text.toLowerCase();
  return BANNED_PHRASES.some((phrase) => lower.includes(phrase));
}

function optionalField(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

export function extractJsonObject(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith("{")) return trimmed;

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) return fenced[1].trim();

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) {
    return trimmed.slice(start, end + 1);
  }

  return trimmed;
}

export function buildMinimalReflectionFromTranscript(transcript: string): Reflection {
  const quote = transcript.trim();
  const clippedQuote =
    quote.length <= 80 ? quote : `${quote.slice(0, 77).trimEnd()}...`;
  const moodWords = quote.split(/\s+/).filter(Boolean).slice(0, 3).join(" ");

  return normalizeReflection({
    mood: moodWords || "neutral",
    emotionalIntensity: 5,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    exactLanguagePattern: clippedQuote,
    concreteObservation: `They said "${quote}".`,
    repeatedSignal: "Nothing repeated clearly in this entry.",
    tensionOrContradiction: "",
    avoidedOrVagueArea: "",
    nextSmallAction: "",
    patternObservations: buildPatternObservationsFromAnalysis({
      exactLanguagePattern: clippedQuote,
      concreteObservation: `They said "${quote}".`,
      repeatedSignal: "Nothing repeated clearly in this entry.",
    }),
  });
}

export function parseReflectionResponse(raw: string, transcript: string): Reflection {
  try {
    return parseReflectionStrict(extractJsonObject(raw));
  } catch (firstError) {
    try {
      return buildMinimalReflectionFromTranscript(transcript);
    } catch {
      throw firstError;
    }
  }
}

function parseReflectionStrict(raw: string): Reflection {
  const parsed = JSON.parse(raw) as Partial<Reflection>;

  const intensity = Number(parsed.emotionalIntensity);
  const themes = Array.isArray(parsed.recurringThemes)
    ? parsed.recurringThemes.filter((theme): theme is string => typeof theme === "string")
    : [];

  const exactLanguagePattern =
    optionalField(parsed.exactLanguagePattern) ??
    optionalField(parsed.mood) ??
    "Entry language";
  const concreteObservation =
    optionalField(parsed.concreteObservation) ??
    optionalField(parsed.exactLanguagePattern) ??
    "Recorded reflection.";
  const repeatedSignal =
    optionalField(parsed.repeatedSignal) ??
    "Nothing repeated clearly in this entry.";

  if (
    typeof parsed.mood !== "string" ||
    !Number.isFinite(intensity) ||
    !exactLanguagePattern ||
    !concreteObservation ||
    !repeatedSignal
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
    exactLanguagePattern,
    concreteObservation,
    repeatedSignal,
    tensionOrContradiction: optionalField(parsed.tensionOrContradiction),
    avoidedOrVagueArea: optionalField(parsed.avoidedOrVagueArea),
    nextSmallAction: optionalField(parsed.nextSmallAction),
    patternObservations: buildPatternObservationsFromAnalysis({
      exactLanguagePattern,
      concreteObservation,
      tensionOrContradiction: optionalField(parsed.tensionOrContradiction),
      repeatedSignal,
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

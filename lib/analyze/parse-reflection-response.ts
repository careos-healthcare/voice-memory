import { buildPatternObservationsFromAnalysis } from "@/lib/observation-language";
import { normalizeReflection } from "@/lib/reflection";
import { buildDeterministicTranscriptConclusion } from "@/lib/explainability/build-conclusion";
import { validateExplainableConclusion } from "@/lib/explainability/validate-explainable-conclusion";
import type { AnalyzePriorEvidence } from "@/lib/analyze/prior-evidence";
import type { Reflection } from "@/types/journal";
import type { PriorExactSnippetSourceMap } from "@/types/explainability";

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
  "this seems important",
  "you sounded uncertain",
  "you mentioned work",
];

const HEDGES = [
  "maybe",
  "i think",
  "i guess",
  "kind of",
  "sort of",
  "not sure",
  "i don't know",
  "probably",
];

const GENERIC_MODEL_CLAIMS = [
  /^your words (?:show|suggest|indicate|reflect)\b/i,
  /^you (?:mentioned|talked about|seem|appear)\b/i,
  /\bthis (?:seems|sounds|feels) important\b/i,
  /\bwork is important to you\b/i,
];

const NGRAM_STOP_WORDS = new Set([
  "a",
  "an",
  "and",
  "are",
  "but",
  "for",
  "from",
  "have",
  "i",
  "in",
  "is",
  "it",
  "of",
  "on",
  "or",
  "that",
  "the",
  "this",
  "to",
  "was",
  "with",
]);

function containsBannedPhrase(text: string): boolean {
  const lower = text.toLowerCase();
  return BANNED_PHRASES.some((phrase) => lower.includes(phrase));
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

export function buildMinimalReflectionFromTranscript(
  transcript: string,
  entryId = "current-entry",
): Reflection {
  const cleaned = cleanTranscript(transcript);
  const repeated = strongestInternalRepeat(cleaned);
  const exactPhrase = repeated?.phrase ?? strongestClause(cleaned);
  const clippedQuote = clipWords(exactPhrase || cleaned, 20, 120);
  const observation =
    explicitTriggerAction(cleaned) ??
    (clippedQuote
      ? `Your words narrow this moment to "${clippedQuote}".`
      : "There is not enough spoken detail for a specific observation yet.");
  const repeatedSignal = repeated
    ? `"${repeated.phrase}" repeats ${repeated.count} times inside this entry.`
    : "Nothing repeated clearly in this entry.";
  const moodWords = cleaned.split(/\s+/).filter(Boolean).slice(0, 3).join(" ");

  return normalizeReflection({
    mood: moodWords || "neutral",
    emotionalIntensity: 5,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
    exactLanguagePattern: clippedQuote,
    concreteObservation: observation,
    repeatedSignal,
    tensionOrContradiction: "",
    avoidedOrVagueArea: "",
    nextSmallAction: "",
    patternObservations: buildPatternObservationsFromAnalysis({
      exactLanguagePattern: clippedQuote,
      concreteObservation: observation,
      repeatedSignal,
    }),
    explainableConclusion: buildDeterministicTranscriptConclusion(entryId, transcript),
  });
}

export function parseReflectionResponse(
  raw: string,
  transcript: string,
  priorEvidence: AnalyzePriorEvidence[] = [],
  entryId = "current-entry",
): Reflection {
  try {
    return parseReflectionStrict(
      extractJsonObject(raw),
      transcript,
      priorEvidence,
      entryId,
    );
  } catch (firstError) {
    try {
      return buildMinimalReflectionFromTranscript(transcript, entryId);
    } catch {
      throw firstError;
    }
  }
}

function parseReflectionStrict(
  raw: string,
  transcript: string,
  priorEvidence: AnalyzePriorEvidence[],
  entryId: string,
): Reflection {
  const parsed = JSON.parse(raw) as Partial<Reflection>;
  const fallback = buildMinimalReflectionFromTranscript(transcript, entryId);
  const modelRepeatedSignal =
    typeof parsed.repeatedSignal === "string" ? parsed.repeatedSignal.trim() : "";
  const claimsCrossRecording =
    /\b(across recordings|prior entry|earlier (?:entry|moment|recording)|both (?:entries|moments|recordings)|supplied prior|recurs?|recurring)\b/i.test(
      `${modelRepeatedSignal} ${parsed.explainableConclusion && typeof parsed.explainableConclusion === "object" && "statement" in parsed.explainableConclusion ? String(parsed.explainableConclusion.statement) : ""}`,
    );
  const priorSnippetSources: PriorExactSnippetSourceMap = new Map(
    priorEvidence.map((item) => [
      item.id,
      {
        ...(item.exactLanguagePattern
          ? { exactLanguagePattern: item.exactLanguagePattern }
          : {}),
        ...(item.concreteObservation
          ? { concreteObservation: item.concreteObservation }
          : {}),
      },
    ]),
  );

  const modelConclusion = validateExplainableConclusion(
    parsed.explainableConclusion,
    new Map([[entryId, transcript]]),
    "explainableConclusion",
    {
      currentEntryId: entryId,
      priorSnippetSources,
      crossRecordingClaim: claimsCrossRecording,
    },
  );
  if (
    !modelConclusion.ok ||
    modelConclusion.conclusion?.provenance.generatedBy !== "model"
  ) {
    return fallback;
  }

  const explainableConclusion = modelConclusion.conclusion;
  const supportingCitation = explainableConclusion.evidence.find(
    (citation) =>
      citation.role === "support" &&
      citation.entryId === entryId &&
      (citation.sourceScope == null || citation.sourceScope === "current_transcript"),
  );
  if (!supportingCitation) return fallback;

  const intensity = Number(parsed.emotionalIntensity);
  const themes = Array.isArray(parsed.recurringThemes)
    ? parsed.recurringThemes.filter((theme): theme is string => typeof theme === "string")
    : [];
  const exactLanguagePattern = supportingCitation.quote;
  const concreteObservation = explainableConclusion.statement.trim();
  const repeatedSignal =
    claimsCrossRecording && modelRepeatedSignal
      ? modelRepeatedSignal
      : (fallback.repeatedSignal ?? "");

  if (
    typeof parsed.mood !== "string" ||
    !Number.isFinite(intensity) ||
    !exactLanguagePattern ||
    !concreteObservation ||
    !repeatedSignal
  ) {
    return fallback;
  }
  if (
    containsBannedPhrase(concreteObservation) ||
    GENERIC_MODEL_CLAIMS.some((pattern) => pattern.test(concreteObservation)) ||
    (claimsCrossRecording && containsBannedPhrase(repeatedSignal))
  ) {
    return fallback;
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
    // These fields are not represented by the strict conclusion schema.
    // Never retain separate model claims that bypass evidence validation.
    tensionOrContradiction: "",
    avoidedOrVagueArea: "",
    nextSmallAction: "",
    patternObservations: buildPatternObservationsFromAnalysis({
      exactLanguagePattern,
      concreteObservation,
      repeatedSignal,
    }),
    explainableConclusion,
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

function cleanTranscript(transcript: string): string {
  return transcript
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 2_000);
}

function clipWords(text: string, maxWords: number, maxChars: number): string {
  const words = text.trim().split(/\s+/).filter(Boolean).slice(0, maxWords);
  const joined = words.join(" ");
  if (joined.length <= maxChars) return joined;
  return `${joined.slice(0, maxChars - 1).trimEnd()}…`;
}

function strongestClause(transcript: string): string {
  const clauses = transcript
    .split(/[.!?;\n]+|,\s+(?=(?:but|so|then|because)\b)/i)
    .map((part) => part.trim())
    .filter(Boolean);
  if (clauses.length === 0) return "";

  return clauses
    .map((clause, index) => ({
      clause,
      score:
        (/\b(?:when|after|before|because|but|then|keep|always|never)\b/i.test(clause)
          ? 5
          : 0) +
        (/\b(?:maybe|not sure|i think|i guess|kind of|sort of)\b/i.test(clause)
          ? 3
          : 0) +
        Math.min(clause.split(/\s+/).length, 18) -
        index * 0.01,
    }))
    .sort((a, b) => b.score - a.score)[0]!.clause;
}

function normalizedWords(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9'\s]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
}

function strongestInternalRepeat(
  transcript: string,
): { phrase: string; count: number } | null {
  const lower = transcript.toLowerCase();
  for (const hedge of HEDGES) {
    const count = lower.split(hedge).length - 1;
    if (count >= 2) return { phrase: hedge, count };
  }

  const words = normalizedWords(transcript);
  const candidates = new Map<string, number>();
  for (let size = 4; size >= 2; size -= 1) {
    for (let index = 0; index <= words.length - size; index += 1) {
      const slice = words.slice(index, index + size);
      if (slice.every((word) => NGRAM_STOP_WORDS.has(word))) continue;
      if (NGRAM_STOP_WORDS.has(slice[0]!) || NGRAM_STOP_WORDS.has(slice.at(-1)!)) {
        continue;
      }
      const phrase = slice.join(" ");
      candidates.set(phrase, (candidates.get(phrase) ?? 0) + 1);
    }
  }

  const repeated = [...candidates.entries()]
    .filter(([, count]) => count >= 2)
    .sort((a, b) => {
      const wordsA = a[0].split(" ").length;
      const wordsB = b[0].split(" ").length;
      return wordsB - wordsA || b[1] - a[1] || b[0].length - a[0].length;
    })[0];
  return repeated ? { phrase: repeated[0], count: repeated[1] } : null;
}

function explicitTriggerAction(transcript: string): string | null {
  const match = transcript.match(
    /\b(when|after|before|whenever|every time|because)\s+([^,.!?;]{2,80})[,;]\s*([^.!?;]{2,160})/i,
  );
  if (!match) return null;
  const marker = match[1]!.toLowerCase();
  const trigger = clipWords(match[2]!, 12, 80);
  const ordered = match[3]!.split(/\s*(?:,\s*)?\b(?:then|so)\b\s*/i);
  let action = clipWords(ordered[0]!, 16, 100);
  action = firstPersonToSecond(action);
  let outcome = ordered.length > 1 ? clipWords(ordered.slice(1).join(" then "), 16, 100) : "";
  outcome = firstPersonToSecond(outcome);
  const lead = marker === "every time"
    ? "Every time"
    : `${marker.charAt(0).toUpperCase()}${marker.slice(1)}`;
  return outcome
    ? `${lead} ${trigger}, ${action}; then ${outcome}.`
    : `${lead} ${trigger}, ${action}.`;
}

function firstPersonToSecond(text: string): string {
  return text
    .replace(/^i am\b/i, "you are")
    .replace(/^i\b/i, "you")
    .replace(/\bmy\b/gi, "your");
}

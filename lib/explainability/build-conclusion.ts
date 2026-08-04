import { buildExactTranscriptCitation } from "@/lib/explainability/citations";
import type { ExplainableConclusion } from "@/types/explainability";

/**
 * Fail-closed fallback: returns no conclusion unless it can cite an exact,
 * non-empty slice of the unmodified canonical transcript.
 */
export function buildDeterministicTranscriptConclusion(
  entryId: string,
  canonicalTranscript: string,
  now = new Date().toISOString(),
): ExplainableConclusion | undefined {
  const bounds = firstMeaningfulSlice(canonicalTranscript);
  if (!bounds) return undefined;
  const quote = canonicalTranscript.slice(bounds.start, bounds.end);
  const citation = buildExactTranscriptCitation(
    entryId,
    canonicalTranscript,
    quote,
  );
  if (!citation) return undefined;

  return {
    id: `deterministic:${entryId}:${bounds.start}-${bounds.end}`,
    statement: `Your words include “${quote}”.`,
    confidence: 55,
    confidencePercent: 55,
    reasoning: [
      "The conclusion repeats an exact slice of the current transcript.",
      "No recurrence or intent is inferred from one bounded citation.",
    ],
    alternativeExplanation: {
      statement: "This wording may describe only this moment.",
      reason: "One transcript slice cannot establish recurrence or intent.",
    },
    uncertainty:
      "This identifies exact wording only; it does not establish a broader pattern.",
    uncertaintyNote:
      "This identifies exact wording only; it does not establish a broader pattern.",
    evidence: [citation],
    alternatives: [
      {
        statement: "This wording may describe only this moment.",
        reason: "One transcript slice cannot establish recurrence or intent.",
      },
    ],
    provenance: {
      generatedBy: "deterministic",
      generatedAt: now,
      schemaVersion: 4,
      promptVersion: "exact-slice-v1",
    },
    history: [{ recordedAt: now, event: "created" }],
  };
}

function firstMeaningfulSlice(
  transcript: string,
): { start: number; end: number } | null {
  const firstNonWhitespace = transcript.search(/\S/u);
  if (firstNonWhitespace < 0) return null;

  const remainder = transcript.slice(firstNonWhitespace);
  const sentenceEnd = remainder.search(/[.!?\n]/u);
  let end =
    sentenceEnd >= 0
      ? firstNonWhitespace + sentenceEnd + 1
      : Math.min(transcript.length, firstNonWhitespace + 120);
  while (end > firstNonWhitespace && /\s/u.test(transcript[end - 1]!)) end -= 1;
  if (end > firstNonWhitespace) {
    const code = transcript.charCodeAt(end - 1);
    if (code >= 0xd800 && code <= 0xdbff && end < transcript.length) end += 1;
  }
  return end > firstNonWhitespace ? { start: firstNonWhitespace, end } : null;
}

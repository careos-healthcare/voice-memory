import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import type { TheoryEvidenceQuote } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

export interface ConfidenceInput {
  supportingCount: number;
  contradictingCount: number;
  spanDays: number;
  lifeAreaCount: number;
  evidenceStrengthScore?: number;
  isMixedContradiction?: boolean;
  failedPredictionLinked?: boolean;
  costEvidenceCount?: number;
  specificityScore?: number;
}

export function computeTheoryConfidence(input: ConfidenceInput): number {
  const { supportingCount, contradictingCount, spanDays, lifeAreaCount } = input;

  let score = 28;
  if (supportingCount >= 2) score += 12;
  if (supportingCount >= 3) score += 10;
  if (supportingCount >= 5) score += 8;
  if (spanDays >= 7) score += 6;
  if (spanDays >= 21) score += 6;
  if (spanDays >= 30) score += 8;
  if (spanDays >= 60) score += 6;
  if (spanDays >= 90) score += 4;
  if (lifeAreaCount >= 2) score += 8;
  if (lifeAreaCount >= 3) score += 4;

  if (input.failedPredictionLinked) score += 10;
  if ((input.costEvidenceCount ?? 0) > 0) {
    score += Math.min(12, 4 + (input.costEvidenceCount ?? 0) * 2);
  }
  if ((input.specificityScore ?? 0) >= 60) score += 6;

  if (input.evidenceStrengthScore !== undefined) {
    score += Math.round(input.evidenceStrengthScore * 0.12);
  }

  const ratio =
    supportingCount + contradictingCount > 0
      ? contradictingCount / (supportingCount + contradictingCount)
      : 0;
  if (ratio >= 0.45) score -= 18;
  else if (ratio >= 0.3) score -= 10;
  else if (contradictingCount > 0) score -= 5;

  if (input.isMixedContradiction) score -= 8;

  return Math.max(0, Math.min(100, Math.round(score)));
}

export function spanDaysForQuotes(
  quotes: TheoryEvidenceQuote[],
  entriesById: Map<string, JournalEntry>,
): number {
  const keys = quotes
    .map((q) => {
      const entry = entriesById.get(q.entryId);
      return entry ? toDayKey(entry.createdAt) : null;
    })
    .filter((k): k is string => Boolean(k))
    .sort();
  if (keys.length < 2) return 0;
  return Math.max(0, daysBetweenKeys(keys[0]!, keys[keys.length - 1]!));
}

export function lifeAreaCountForQuotes(
  quotes: TheoryEvidenceQuote[],
  entries: JournalEntry[],
): number {
  const ids = quotes.map((q) => q.entryId);
  return linkedAreasForEntries(entries, ids).length;
}

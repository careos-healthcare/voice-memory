import { gateContinuityQuote } from "@/lib/continuity/continuity-quality-gate";
import { isGenericResurfacing } from "@/lib/resurfacing/genericity-filter";
import {
  isPhraseOnResurfacingCooldown,
  phraseKeyFromQuote,
  userFeedbackPenaltyForPhrase,
} from "@/lib/resurfacing/resurfacing-feedback";

const PENALTY_NOT_ME_BLOCK = 35;
const PENALTY_MISSED_SOFT = 12;
import type { ReturnThread } from "@/types/return-thread";

export interface ResurfacingScoreBreakdown {
  quoteMatchScore: number;
  recurrenceScore: number;
  emotionalSpecificityScore: number;
  userFeedbackPenalty: number;
  finalResurfacingConfidence: number;
}

export type ResurfacingRecurrenceReason =
  | "repeated_phrase"
  | "recurring_person"
  | "recurring_uncertainty"
  | "same_time_window"
  | "phrase_memory";

const MIN_SHOW_CONFIDENCE = 58;

export function scoreQuoteMatch(quote: string): number {
  const gated = gateContinuityQuote(quote);
  if (!gated) return 0;
  let score = 40;
  if (gated.length >= 12) score += 15;
  if (gated.length >= 24) score += 10;
  if (/^["'].*["']$/.test(quote.trim())) score += 5;
  if (isGenericResurfacing(gated)) score -= 25;
  return Math.max(0, Math.min(100, score));
}

export function scoreRecurrence(appearances: number, gapDays?: number): number {
  let score = appearances * 12;
  if (appearances >= 3) score += 10;
  if (gapDays !== undefined && gapDays >= 1 && gapDays <= 21) score += 8;
  return Math.max(0, Math.min(100, score));
}

export function scoreEmotionalSpecificity(threadType?: ReturnThread["type"]): number {
  switch (threadType) {
    case "repeated_phrase":
      return 72;
    case "recurring_person":
      return 68;
    case "recurring_uncertainty":
      return 55;
    default:
      return 45;
  }
}

export function buildResurfacingScores(input: {
  quote: string;
  appearances: number;
  gapDays?: number;
  threadType?: ReturnThread["type"];
}): ResurfacingScoreBreakdown {
  const phraseKey = phraseKeyFromQuote(input.quote);
  const quoteMatchScore = scoreQuoteMatch(input.quote);
  const recurrenceScore = scoreRecurrence(input.appearances, input.gapDays);
  const emotionalSpecificityScore = scoreEmotionalSpecificity(input.threadType);
  const userFeedbackPenalty = phraseKey ? userFeedbackPenaltyForPhrase(phraseKey) : 0;

  const raw =
    quoteMatchScore * 0.45 +
    recurrenceScore * 0.35 +
    emotionalSpecificityScore * 0.2 -
    userFeedbackPenalty;

  const finalResurfacingConfidence = Math.max(0, Math.min(100, Math.round(raw)));

  return {
    quoteMatchScore,
    recurrenceScore,
    emotionalSpecificityScore,
    userFeedbackPenalty,
    finalResurfacingConfidence,
  };
}

export function shouldShowResurfacing(
  scores: ResurfacingScoreBreakdown,
  quote: string,
): boolean {
  const phraseKey = phraseKeyFromQuote(quote.replace(/^["']|["']$/g, ""));
  if (phraseKey && isPhraseOnResurfacingCooldown(phraseKey)) return false;

  const penalty = phraseKey ? userFeedbackPenaltyForPhrase(phraseKey) : 0;
  if (penalty >= PENALTY_NOT_ME_BLOCK) return false;

  // "Missed" is a soft nudge — restore up to missed penalty for the show threshold only.
  const thresholdConfidence =
    penalty > 0 && penalty <= PENALTY_MISSED_SOFT
      ? scores.finalResurfacingConfidence + penalty
      : scores.finalResurfacingConfidence;

  return thresholdConfidence >= MIN_SHOW_CONFIDENCE;
}

export function whySurfacedLine(
  reason: ResurfacingRecurrenceReason,
  uncertain: boolean,
): string {
  const base =
    reason === "repeated_phrase"
      ? "You used these words on more than one day."
      : reason === "recurring_person"
        ? "The same person came up again."
        : reason === "recurring_uncertainty"
          ? "This worry showed up in your words before."
          : reason === "same_time_window"
            ? "Something similar came back around the same rhythm."
            : "A phrase you spoke before came back.";

  if (uncertain) {
    return `This might be connected — ${base.charAt(0).toLowerCase()}${base.slice(1)}`;
  }
  return base;
}

export function mapThreadTypeToReason(
  type: ReturnThread["type"],
): ResurfacingRecurrenceReason {
  if (type === "recurring_person") return "recurring_person";
  if (type === "recurring_uncertainty") return "recurring_uncertainty";
  return "repeated_phrase";
}

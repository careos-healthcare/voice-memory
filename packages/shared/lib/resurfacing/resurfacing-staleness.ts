import {
  getResurfacingFatiguePenalty,
  getResurfacingFatigueRecord,
  shouldSuppressResurfacingNote,
} from "@/lib/resurfacing/resurfacing-fatigue";
import {
  getClusterCooldownStatus,
  isPhraseOnResurfacingCooldown,
  phraseKeyFromQuote,
  userFeedbackPenaltyForPhrase,
} from "@/lib/resurfacing/resurfacing-feedback";
import type { ResurfacingCooldownStatus } from "@/types/resurfacing-evidence";

export const STALE_CALLBACK_DAYS = 21;
export const STALE_WITHOUT_REINFORCEMENT_DAYS = 28;
const PENALTY_NOT_ME_RETIRE = 35;
const FATIGUE_RETIRED_DISMISSALS = 3;

export function resolveCooldownStatus(input: {
  phraseKey: string;
  noteId?: string;
  stalenessDays: number;
  priorRejection: number;
}): ResurfacingCooldownStatus {
  if (input.priorRejection >= PENALTY_NOT_ME_RETIRE) return "retired";
  if (input.phraseKey && isPhraseOnResurfacingCooldown(input.phraseKey)) {
    return "cooldown";
  }
  const cluster = getClusterCooldownStatus(input.phraseKey);
  if (cluster === "retired" || cluster === "cooldown") return cluster;

  if (input.noteId) {
    const row = getResurfacingFatigueRecord(input.noteId);
    if (row && row.repeatedDismissals >= FATIGUE_RETIRED_DISMISSALS) {
      return "retired";
    }
    if (shouldSuppressResurfacingNote(input.noteId)) return "fatigued";
    const penalty = getResurfacingFatiguePenalty(input.noteId);
    if (penalty >= 24) return "fatigued";
  }

  if (input.stalenessDays >= STALE_WITHOUT_REINFORCEMENT_DAYS) return "fatigued";

  return "clear";
}

export function isStaleWithoutReinforcement(
  stalenessDays: number,
  priorAcceptance: number,
): boolean {
  if (priorAcceptance > 0 && stalenessDays < STALE_CALLBACK_DAYS + 14) {
    return false;
  }
  return stalenessDays >= STALE_WITHOUT_REINFORCEMENT_DAYS;
}

export function stalenessConfidencePenalty(stalenessDays: number): number {
  if (stalenessDays < STALE_CALLBACK_DAYS) return 0;
  if (stalenessDays < STALE_WITHOUT_REINFORCEMENT_DAYS) {
    return Math.min(18, Math.floor((stalenessDays - STALE_CALLBACK_DAYS) * 0.8));
  }
  return 28 + Math.min(20, stalenessDays - STALE_WITHOUT_REINFORCEMENT_DAYS);
}

export function phraseKeyFromText(text: string): string {
  return phraseKeyFromQuote(text);
}

export function rejectionPenaltyForPhrase(phraseKey: string): number {
  return userFeedbackPenaltyForPhrase(phraseKey);
}

import { callbackInteractionSignals } from "@/lib/callback-interaction-signals";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { entryRevisitationNotes, homepageRevisitationNotes } from "@/lib/memory/revisitation";
import { isTopicRecurrenceCopy } from "@/lib/refinement/knows-me-moments";
import { scoreCallbackTuning } from "@/lib/refinement/callback-tuning";
import {
  REVISIT_REWARD_SUPPRESS_ID,
  REVISIT_REWARD_SUPPRESS_TEXT,
} from "@/lib/refinement/callback-suppression";
import {
  REOPEN_PAYOFF_STRONG,
  scoreReopenPayoff,
} from "@/lib/refinement/reopen-payoff";
import { detectRevisitFatigue } from "@/lib/refinement/revisit-sequencing";
import {
  directScore,
  hedgeScore,
  quoteSimilarity,
} from "@/lib/refinement/then-vs-now-quotes";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { entryRevisitRewardCandidates } from "@/lib/refinement/knows-me-moments";
import {
  ADVICE_RESURFACING_RE,
  isBlockedResurfacingCopy,
  isGenericResurfacingCopy,
  OVERCLAIM_RESURFACING_RE,
  PRODUCTIVITY_RESURFACING_RE,
} from "@/lib/revisit/resurfacing-copy";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  RevisitQualityClassification,
  RevisitQualityDimensions,
  RevisitQualityFlag,
  RevisitQualityVerdict,
} from "@/types/revisit-quality";

export const REVISIT_QUALITY_WEAK_MAX = 44;
export const REVISIT_QUALITY_MEANINGFUL_MIN = 52;
export const REVISIT_QUALITY_DURABLE_MIN = 62;

const GENERIC_COPY_RE =
  /\b(you sound different|appeared again|similar theme|worth revisiting|older reflection|this thread|pattern|insight|continuity|intelligence|may feel|might feel|seems to|appears to)\b/i;

const OVERCLAIM_RE =
  /\b(completely changed|totally different|transformed|dramatically|profound shift|deeply shifted|major shift|everything changed|fundamentally different|clearly improved|definitely changed)\b/i;

const SUMMARY_RE =
  /\b(in summary|to summarize|overall|looking back|recap|highlights|key takeaways)\b/i;

const UNIVERSAL_TEMPLATE_RE =
  /^(You sound different now\.|This used to take up more room\.|You had not named this yet\.)$/i;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function linkedEntryIds(note: MemoryNote): string[] {
  return [note.pastEntryId, note.entryId].filter(Boolean) as string[];
}

/** Whether a note belongs to the revisit / resurfacing quality surface. */
export function isRevisitQualityNote(note: MemoryNote): boolean {
  return (
    note.id.startsWith("revisit-") ||
    note.id.startsWith("resurface-") ||
    note.id.startsWith("knows-me-") ||
    note.id.startsWith("tvn-") ||
    note.id.startsWith("revisit-reward-") ||
    note.category === "returned"
  );
}

function scoreSpecificity(note: MemoryNote, tuningSpecificity: number): number {
  let score = Math.min(tuningSpecificity, 40);
  const text = note.text.trim();
  if (note.pastQuote?.trim() && note.currentQuote?.trim()) score += 12;
  if (/\b(mum|dad|mother|father|work|home|[A-Z][a-z]{2,})\b/.test(text)) score += 10;
  if (note.pastDateLabel && note.currentDateLabel) score += 8;
  return Math.min(score, 100);
}

function scoreSurprise(payoffTotal: number, gapDays: number, repeatedPhraseScore: number): number {
  let score = Math.min(Math.round(payoffTotal * 0.45), 45);
  if (gapDays >= 30) score += 18;
  else if (gapDays >= 14) score += 10;
  else if (gapDays >= 7) score += 8;
  score += Math.min(Math.round(repeatedPhraseScore * 0.2), 14);
  return Math.min(score, 100);
}

function scoreBeforeAfterContrast(note: MemoryNote, tuningContrast: number, payoffTotal: number): number {
  let score = Math.min(Math.round(tuningContrast * 1.4), 50);
  score += Math.min(Math.round(payoffTotal * 0.35), 35);
  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    const sim = quoteSimilarity(note.pastQuote, note.currentQuote);
    score += Math.round((1 - sim) * 20);
  }
  return Math.min(score, 100);
}

function scoreWordingPreservation(note: MemoryNote, past?: JournalEntry, current?: JournalEntry): number {
  const pastText = note.pastQuote?.trim() || past?.reflection.exactLanguagePattern?.trim() || past?.transcript || "";
  const currentText =
    note.currentQuote?.trim() || current?.reflection.exactLanguagePattern?.trim() || current?.transcript || "";
  if (!pastText || !currentText) return 20;
  let score = 24;
  if (past?.reflection.exactLanguagePattern?.trim()) score += 16;
  if (current?.reflection.exactLanguagePattern?.trim()) score += 16;
  const hedgeDrop = hedgeScore(pastText) - hedgeScore(currentText);
  const directGain = directScore(currentText) - directScore(pastText);
  score += Math.max(0, hedgeDrop) * 6;
  score += Math.max(0, directGain) * 6;
  return Math.min(score, 100);
}

function scoreEmotionalDistance(past?: JournalEntry, current?: JournalEntry, gapDays = 0): number {
  if (!past || !current) return gapDays >= 14 ? 30 : 12;
  const intensityDelta = Math.abs(past.reflection.emotionalIntensity - current.reflection.emotionalIntensity);
  let score = 16 + Math.round(intensityDelta * 10);
  if (past.reflection.mood !== current.reflection.mood) score += 12;
  if (gapDays >= 30) score += 16;
  else if (gapDays >= 14) score += 8;
  return Math.min(score, 100);
}

function scorePhotoAudioSupport(past?: JournalEntry, current?: JournalEntry): number {
  let score = 0;
  if (past?.photo?.photoId) score += 24;
  if (current?.photo?.photoId) score += 24;
  if (past?.audioId) score += 16;
  if (current?.audioId) score += 16;
  if (past?.audioId && current?.audioId) score += 12;
  return Math.min(score, 100);
}

function scoreFollowUpConversion(note: MemoryNote, entryIds: string[]): number {
  const signals = callbackInteractionSignals(note.id, entryIds);
  let score = 0;
  if (signals.followupContinued) score += 50;
  if (signals.memoryMomentCopied) score += 20;
  if (signals.rereadCount > 0) score += Math.min(signals.rereadCount * 8, 24);
  return Math.min(score, 100);
}

function scoreBookmarkCopyAfterRevisit(note: MemoryNote, entryIds: string[]): number {
  const signals = callbackInteractionSignals(note.id, entryIds);
  let score = 0;
  if (signals.bookmarked) score += 55;
  if (signals.memoryMomentCopied) score += 35;
  return Math.min(score, 100);
}

function scoreDelayedReflectionAfterRevisit(entryIds: string[]): number {
  const events = readLocalEvents();
  const match = events.some(
    (event) =>
      (event.name === "remembered_later_delayed_reflection" ||
        event.name === "followup_recording_completed" ||
        event.name === "reflection_after_prompt") &&
      entryIds.some((id) => event.meta?.entryId === id || event.meta?.noteId?.includes(id)),
  );
  return match ? 72 : 0;
}

function scoreRepeatReopenSameEntry(entryIds: string[]): number {
  const signals = callbackInteractionSignals(entryIds[0] ?? "", entryIds);
  if (signals.revisitCount >= 3) return 90;
  if (signals.revisitCount === 2) return 62;
  if (signals.revisitCount === 1) return 28;
  return 0;
}

function scoreRepeatedPhrase(note: MemoryNote, entries: JournalEntry[]): number {
  if (!note.pastEntryId || !note.entryId) return 0;
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;

  const phrases = buildPhraseMemory(entries);
  for (const record of phrases) {
    if (record.count < 2) continue;
    if (!record.entryIds.includes(past.id) || !record.entryIds.includes(current.id)) continue;
    const gap = daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
    if (gap >= 7) return Math.min(88, 52 + Math.min(gap, 21) + record.count * 4);
  }

  if (note.id.includes("phrase")) return 48;
  return 0;
}

function scoreGenericityRisk(text: string, note: MemoryNote): number {
  let risk = 0;
  if (GENERIC_COPY_RE.test(text)) risk += 28;
  if (isGenericResurfacingCopy(text)) risk += 40;
  if (isBlockedResurfacingCopy(text)) risk += 36;
  if (ADVICE_RESURFACING_RE.test(text)) risk += 44;
  if (OVERCLAIM_RESURFACING_RE.test(text)) risk += 38;
  if (PRODUCTIVITY_RESURFACING_RE.test(text)) risk += 50;
  if (SUMMARY_RE.test(text)) risk += 22;
  if (UNIVERSAL_TEMPLATE_RE.test(text.trim())) risk += 34;
  if (isTopicRecurrenceCopy(text)) risk += 36;
  if (!note.pastQuote?.trim() && !note.currentQuote?.trim() && text.split(/\s+/).length <= 6) {
    risk += 22;
  }
  if (
    note.id.startsWith("resurface-topic-") &&
    !note.pastQuote?.trim() &&
    !note.currentQuote?.trim()
  ) {
    risk += 28;
  }
  return Math.min(risk, 100);
}

function scoreOverclaimRisk(text: string): number {
  let risk = 0;
  if (OVERCLAIM_RE.test(text)) risk += 48;
  if (/\b(clearly|definitely|always|never)\b/i.test(text) && !/\b(mum|dad|work|[A-Z][a-z]{2,})\b/.test(text)) {
    risk += 12;
  }
  return Math.min(risk, 100);
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (past && current) {
    return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
  }
  if (past) return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(new Date().toISOString()));
  return 0;
}

function buildFlags(
  dimensions: RevisitQualityDimensions,
  classification: RevisitQualityClassification,
  payoffSuppressed: boolean,
  suppressReason?: string,
): RevisitQualityFlag[] {
  const flags: RevisitQualityFlag[] = [];
  if (dimensions.genericityRisk >= 55) flags.push("generic_copy");
  if (dimensions.overclaimRisk >= 50) flags.push("overclaimed_copy");
  if (
    payoffSuppressed &&
    (suppressReason === "informational_continuity" || suppressReason === "topical_similarity")
  ) {
    flags.push("informational_only");
  }
  if (dimensions.beforeAfterContrast < 35 && dimensions.specificity < 40) {
    flags.push("weak_contrast");
  }
  if (classification === "durable_revisit" || classification === "meaningful_revisit") {
    flags.push("high_quality");
  }
  return flags;
}

function classifyRevisit(
  total: number,
  dimensions: RevisitQualityDimensions,
  payoffTotal: number,
  payoffSuppressed: boolean,
  suppressReason?: string,
): RevisitQualityClassification {
  if (
    dimensions.genericityRisk >= 55 ||
    (dimensions.overclaimRisk >= 50 && dimensions.specificity < 40) ||
    total <= REVISIT_QUALITY_WEAK_MAX
  ) {
    return "weak_revisit";
  }

  if (
    payoffSuppressed &&
    (suppressReason === "informational_continuity" ||
      suppressReason === "topical_similarity" ||
      suppressReason === "emotionally_flat")
  ) {
    return "informational_revisit";
  }

  const durableSignals =
    dimensions.followUpConversion >= 40 ||
    dimensions.bookmarkCopyAfterRevisit >= 35 ||
    (dimensions.repeatReopenSameEntry >= 30 && dimensions.delayedReflectionAfterRevisit >= 25);

  if (total >= REVISIT_QUALITY_DURABLE_MIN && durableSignals) {
    return "durable_revisit";
  }

  if (total >= REVISIT_QUALITY_MEANINGFUL_MIN && payoffTotal >= 54 && !payoffSuppressed) {
    return "meaningful_revisit";
  }

  if (total >= 40) return "informational_revisit";
  return "weak_revisit";
}

function computeTotal(dimensions: RevisitQualityDimensions): number {
  const positive =
    dimensions.specificity * 0.14 +
    dimensions.surprise * 0.1 +
    dimensions.beforeAfterContrast * 0.18 +
    dimensions.wordingPreservation * 0.12 +
    dimensions.emotionalDistance * 0.1 +
    dimensions.photoAudioSupport * 0.06 +
    dimensions.followUpConversion * 0.08 +
    dimensions.bookmarkCopyAfterRevisit * 0.06 +
    dimensions.delayedReflectionAfterRevisit * 0.08 +
    dimensions.repeatReopenSameEntry * 0.08;

  const penalty = dimensions.genericityRisk * 0.22 + dimensions.overclaimRisk * 0.18;
  return Math.max(0, Math.round(positive - penalty));
}

/** Score whether a revisit moment emotionally lands — internal only. */
export function assessRevisitQuality(
  note: MemoryNote,
  entries: JournalEntry[],
): RevisitQualityVerdict {
  const text = note.text.trim();
  const entryIds = linkedEntryIds(note);
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  const gapDays = gapDaysForNote(note, entries);
  const tuning = scoreCallbackTuning(note, entries);
  const payoff = scoreReopenPayoff(note, entries);
  const repeatedPhraseScore = scoreRepeatedPhrase(note, entries);

  const dimensions: RevisitQualityDimensions = {
    specificity: scoreSpecificity(note, tuning.specificity) + Math.min(repeatedPhraseScore * 0.15, 12),
    surprise: scoreSurprise(payoff.total, gapDays, repeatedPhraseScore),
    beforeAfterContrast: scoreBeforeAfterContrast(note, tuning.emotionalContrast, payoff.total),
    wordingPreservation: scoreWordingPreservation(note, past, current),
    emotionalDistance: scoreEmotionalDistance(past, current, gapDays),
    photoAudioSupport: scorePhotoAudioSupport(past, current),
    followUpConversion: scoreFollowUpConversion(note, entryIds),
    bookmarkCopyAfterRevisit: scoreBookmarkCopyAfterRevisit(note, entryIds),
    delayedReflectionAfterRevisit: scoreDelayedReflectionAfterRevisit(entryIds),
    repeatReopenSameEntry: scoreRepeatReopenSameEntry(entryIds),
    genericityRisk: scoreGenericityRisk(text, note),
    overclaimRisk: scoreOverclaimRisk(text),
  };

  const total = computeTotal(dimensions);
  const classification = classifyRevisit(
    total,
    dimensions,
    payoff.total,
    payoff.suppressed,
    payoff.suppressReason,
  );
  const flags = buildFlags(dimensions, classification, payoff.suppressed, payoff.suppressReason);
  const protectedPattern =
    classification === "durable_revisit" ||
    (classification === "meaningful_revisit" &&
      dimensions.beforeAfterContrast >= 60 &&
      dimensions.specificity >= 50) ||
    payoff.total >= REOPEN_PAYOFF_STRONG;

  const hardSuppressed =
    REVISIT_REWARD_SUPPRESS_ID.test(note.id) ||
    REVISIT_REWARD_SUPPRESS_TEXT.test(text) ||
    isTopicRecurrenceCopy(text) ||
    isBlockedResurfacingCopy(text);

  const suppressed =
    hardSuppressed ||
    classification === "weak_revisit" ||
    dimensions.genericityRisk >= 55 ||
    (dimensions.overclaimRisk >= 55 && dimensions.specificity < 35);

  return {
    total,
    classification,
    dimensions,
    flags,
    suppressed: suppressed && !protectedPattern,
    protected: protectedPattern,
    entryId: note.entryId,
    noteId: note.id,
    text,
  };
}

export function shouldSuppressRevisitQuality(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  if (!isRevisitQualityNote(note)) return false;
  return assessRevisitQuality(note, entries).suppressed;
}

export function isProtectedRevisitQuality(verdict: RevisitQualityVerdict): boolean {
  return verdict.protected;
}

export function applyRevisitQualityRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  if (!isRevisitQualityNote(note)) return baseScore;
  const verdict = assessRevisitQuality(note, entries);
  if (verdict.suppressed) return baseScore - 40;
  if (verdict.protected) return baseScore + 14;
  if (verdict.classification === "weak_revisit") return baseScore - 28;
  if (verdict.classification === "informational_revisit") return baseScore - 10;
  if (verdict.classification === "meaningful_revisit") return baseScore + 6;
  if (verdict.classification === "durable_revisit") return baseScore + 12;
  return baseScore;
}

/** Filter revisit notes — prefer quiet over generic copy. */
export function pickQualityRevisitNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
): MemoryNote[] {
  return notes.filter((note) => {
    if (!isRevisitQualityNote(note)) return true;
    return !shouldSuppressRevisitQuality(note, entries);
  });
}

export function collectRevisitQualityCandidates(entries: JournalEntry[]): MemoryNote[] {
  const sorted = sortedEntries(entries);
  const byId = new Map<string, MemoryNote>();

  const remember = (note: MemoryNote | null | undefined) => {
    if (!note?.id) return;
    byId.set(note.id, note);
  };

  for (const note of homepageRevisitationNotes(sorted)) {
    remember(note);
  }

  for (const entry of sorted) {
    for (const note of entryRevisitationNotes(sorted, entry.id)) {
      remember(note);
    }
    for (const note of entryRevisitRewardCandidates(sorted, entry.id)) {
      remember(note);
    }
    const memoryNotes = entryMemoryNotes(sorted, entry.id);
    remember(memoryNotes.primaryCallback);
    for (const note of memoryNotes.thenVsNow) {
      if (isRevisitQualityNote(note)) remember(note);
    }
  }

  return [...byId.values()];
}

export function buildRevisitFatigueRiskSummary(
  rows: RevisitQualityVerdict[],
): import("@/types/revisit-quality").RevisitFatigueRiskSummary {
  const fatigue = detectRevisitFatigue();
  const weakCount = rows.filter((row) => row.classification === "weak_revisit").length;
  const weakRevisitRatio = rows.length > 0 ? Math.round((weakCount / rows.length) * 100) : 0;

  let recommendation = "Revisit cadence looks manageable.";
  if (fatigue.active && weakRevisitRatio >= 50) {
    recommendation = "High revisit volume with many weak moments — tighten prompt selection.";
  } else if (fatigue.active) {
    recommendation = "Revisit fatigue active — protect spacing and high-quality lines only.";
  } else if (weakRevisitRatio >= 60) {
    recommendation = "Many weak revisit lines — cut generic copy before adding more callbacks.";
  }

  return {
    active: fatigue.active,
    recentRevisits: fatigue.score,
    weakRevisitRatio,
    recommendation,
  };
}

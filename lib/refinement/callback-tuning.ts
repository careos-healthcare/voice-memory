import { callbackInteractionSignals } from "@/lib/callback-interaction-signals";
import { weightMemoryNote } from "@/lib/memory/emotional-weight";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  isBlockedResurfacingCopy,
} from "@/lib/revisit/resurfacing-copy";
import { LOW_CONTRAST_RESURFACE_ID } from "@/lib/refinement/callback-suppression";
import { isTopicRecurrenceCopy } from "@/lib/refinement/revisit-reward-copy";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { applyLoopOptimizationBoost } from "@/lib/retention/loop-optimization";
import { SCORE_WEAK } from "@/lib/refinement/score-thresholds";
import {
  applyRevisitQualityRankAdjustment,
  isRevisitQualityNote,
  shouldSuppressRevisitQuality,
} from "@/lib/revisit/revisit-quality";
import {
  applyResurfacingConfidenceRankAdjustment,
  shouldSuppressResurfacingConfidence,
} from "@/lib/revisit/resurfacing-confidence";
import {
  applyResurfacingTimingRankAdjustment,
  shouldSuppressResurfacingTiming,
} from "@/lib/revisit/resurfacing-timing";
import { applyBehavioralRankingBoost } from "@/lib/resurfacing/behavioral-ranking";
import { shouldSuppressResurfacingNote } from "@/lib/resurfacing/resurfacing-fatigue";
import {
  filterCallbacksByModeDiversity,
  getReturnModeFatiguePenalty,
} from "@/lib/resurfacing/return-modes";
import {
  hasDetectableChange,
  shouldSuppressWithoutDetectableChange,
} from "@/lib/resurfacing/resurfacing-change-detection";
import { shouldSuppressResurfacingByFrequency } from "@/lib/resurfacing/resurfacing-frequency";
import {
  naturalizeResurfacingNote,
  passesNaturalVoiceGate,
  syntheticVoicePenalty,
} from "@/lib/resurfacing/resurfacing-natural-voice";
import { passesResurfacingSpecificityGate } from "@/lib/resurfacing/resurfacing-specificity-gate";
import { applyCallbackLearningRankAdjustment } from "@/lib/revisit/callback-learning";
import { hasConcreteResurfacingEvidence } from "@/lib/resurfacing/evidence-engine";
import {
  isGenericResurfacing,
  passesResurfacingGenericityGate,
  scoreSpecificity,
} from "@/lib/resurfacing/genericity-filter";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export interface CallbackTuningScore {
  total: number;
  emotionalContrast: number;
  specificity: number;
  simplicity: number;
  rereadLikelihood: number;
  revisitLikelihood: number;
  memorability: number;
  emotionalTiming: number;
  quoteQuality: number;
  penalties: number;
}

const GENERIC_RE =
  /\b(may feel|might feel|appears to|seems to|pattern|insight|analysis|observed|continuity|intelligence|engine|shift|recurring theme|journey|growth|insights)\b/i;
const THERAPY_RE =
  /\b(process|journey|validate|hold space|check in with yourself|self-care|healing|unpack)\b/i;
const EXPLAIN_RE =
  /\b(because|which means|this suggests|indicates that|in other words|over time)\b/i;
const TEMPLATE_RE =
  /^(You |This was |This has been |An older |There is more |More of your |Your archive )/i;

const PREFERRED_CONTRAST_RE =
  /\b(this used to feel heavier|still circling this here|stopped apologising|sound more direct now|reads like an earlier version|said something similar|came back in different words|same concern showed up|used to sound heavier|named this before)\b/i;

const LOW_CONTRAST_RESURFACE_RE = LOW_CONTRAST_RESURFACE_ID;

function linkedEntries(note: MemoryNote, entries: JournalEntry[]): JournalEntry[] {
  return linkedEntriesForNote(note, entries);
}

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

function quoteSimilarity(a: string, b: string): number {
  const left = new Set(a.toLowerCase().split(/\s+/));
  const right = new Set(b.toLowerCase().split(/\s+/));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
}

function scorePenalties(text: string, note: MemoryNote): number {
  let penalty = 0;
  if (GENERIC_RE.test(text)) penalty += 14;
  if (THERAPY_RE.test(text)) penalty += 18;
  if (EXPLAIN_RE.test(text)) penalty += 10;
  if (TEMPLATE_RE.test(text)) penalty += 8;
  if (wordCount(text) > 12) penalty += 6;
  if (text.includes(" — ") || text.includes(";")) penalty += 4;
  if (isTopicRecurrenceCopy(text)) penalty += 24;
  if (isBlockedResurfacingCopy(text)) penalty += 28;
  if (isGenericResurfacing(text)) penalty += 32;
  if (LOW_CONTRAST_RESURFACE_RE.test(note.id)) penalty += 18;
  penalty += syntheticVoicePenalty(text);
  return penalty;
}

/** Rank surfaced callbacks for emotional precision — internal only. */
export function scoreCallbackTuning(
  note: MemoryNote,
  entries: JournalEntry[],
): CallbackTuningScore {
  const text = note.text.trim();
  const words = wordCount(text);
  const entryIds = [note.pastEntryId, note.entryId].filter(Boolean) as string[];
  const signals = callbackInteractionSignals(note.id, entryIds);
  const weight = weightMemoryNote(note, entries);

  const hasQuotes = Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
  const hasOneQuote = Boolean(note.pastQuote?.trim() || note.currentQuote?.trim());
  const linked = linkedEntries(note, entries);

  let emotionalContrast = 12;
  if (hasQuotes) {
    const sim = quoteSimilarity(note.pastQuote!, note.currentQuote!);
    emotionalContrast += Math.round((1 - sim) * 28);
  } else if (note.pastQuote || note.currentQuote) {
    emotionalContrast += 10;
  }
  if (PREFERRED_CONTRAST_RE.test(text)) emotionalContrast += 18;
  if (/\b(quieter|different|faded|calmer|heavier|unfinished|direct|earlier|circling|apolog)\b/i.test(text)) {
    emotionalContrast += 8;
  }
  if (note.id.startsWith("knows-me-")) emotionalContrast += 10;

  if (linked.length >= 2) {
    const intensities = linked.map((entry) => entry.reflection.emotionalIntensity);
    const intensityDelta = Math.max(...intensities) - Math.min(...intensities);
    if (intensityDelta >= 1.5) emotionalContrast += 10 + Math.round(intensityDelta * 2);
  }

  let specificity = Math.round(scoreSpecificity(text, note) * 0.45);
  if (hasOneQuote) specificity += 14;
  if (/\b(mum|dad|work|home|Sarah|[A-Z][a-z]{2,})\b/.test(text)) specificity += 10;
  if (note.pastDateLabel && note.currentDateLabel) specificity += 6;
  if (note.id.startsWith("knows-me-named") || note.id.startsWith("knows-me-direct")) {
    specificity += 8;
  }

  let simplicity = 18;
  if (words <= 6) simplicity += 16;
  else if (words <= 9) simplicity += 10;
  else if (words <= 12) simplicity += 4;
  else simplicity -= 8;

  const rereadLikelihood = Math.min(24, signals.rereadCount * 8 + (signals.dwellMs > 8000 ? 8 : 0));
  const revisitLikelihood = Math.min(20, signals.revisitCount * 10 + (signals.bookmarked ? 10 : 0));

  let memorability = 8;
  if (signals.memoryMomentCopied) memorability += 16;
  if (signals.followupContinued) memorability += 12;
  if (signals.bookmarked) memorability += 10;
  if (hasQuotes) memorability += 6;

  let emotionalTiming = Math.min(20, Math.round(weight / 6));
  if (note.id.includes("revisit-") || note.id.includes("resurface-")) emotionalTiming += 6;

  let quoteQuality = 0;
  if (note.pastQuote?.trim()) quoteQuality += 8;
  if (note.currentQuote?.trim()) quoteQuality += 8;
  if (hasQuotes && quoteSimilarity(note.pastQuote!, note.currentQuote!) < 0.75) {
    quoteQuality += 8;
  }

  if (linked.some((entry) => entry.audioId)) quoteQuality += 10;

  if (linked.length >= 2) {
    const sortedLinked = [...linked].sort(
      (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
    );
    const gap = daysBetweenKeys(
      toDayKey(sortedLinked[0].createdAt),
      toDayKey(sortedLinked[sortedLinked.length - 1].createdAt),
    );
    if (gap >= 7) {
      emotionalTiming += Math.min(Math.round(gap / 5), 12);
      memorability += 6;
    }
    if (gap >= 14) emotionalTiming += Math.min(Math.round(gap / 7), 8);
  }

  if (linked.some((entry) => entry.photo?.photoId)) quoteQuality += 8;

  if (note.id.startsWith("knows-me-wording") || note.id.startsWith("knows-me-apology")) {
    emotionalContrast += 8;
  }
  if (note.id.startsWith("knows-me-phrase-gone") || note.id.startsWith("knows-me-circling")) {
    emotionalContrast += 10;
  }
  if (note.id.includes("resurface-phrase") || note.id.includes("phrase_return")) {
    emotionalContrast += 14;
    specificity += 12;
  }

  const penalties = scorePenalties(text, note) + getReturnModeFatiguePenalty(note, entries);
  const total = Math.max(
    0,
    emotionalContrast +
      specificity +
      simplicity +
      rereadLikelihood +
      revisitLikelihood +
      memorability +
      emotionalTiming +
      quoteQuality -
      penalties,
  );

  return {
    total,
    emotionalContrast,
    specificity,
    simplicity,
    rereadLikelihood,
    revisitLikelihood,
    memorability,
    emotionalTiming,
    quoteQuality,
    penalties,
  };
}

export function rankCallbacksByTuning(
  notes: MemoryNote[],
  entries: JournalEntry[],
): Array<{ note: MemoryNote; score: CallbackTuningScore }> {
  return notes
    .map((note) => ({ note, score: scoreCallbackTuning(note, entries) }))
    .sort((a, b) => b.score.total - a.score.total || b.note.confidence - a.note.confidence);
}

export function pickBestCallback(
  notes: MemoryNote[],
  entries: JournalEntry[],
  minTotal = SCORE_WEAK,
): MemoryNote | null {
  const backed = notes
    .map((note) => naturalizeResurfacingNote(note, entries))
    .filter(
      (note) =>
        !shouldSuppressResurfacingByFrequency(note) &&
        !shouldSuppressWithoutDetectableChange(note, entries) &&
        hasDetectableChange(note, entries) &&
        hasConcreteResurfacingEvidence(note, entries) &&
        passesResurfacingSpecificityGate(note, { evidenceBacked: true }) &&
        passesNaturalVoiceGate(note) &&
        passesResurfacingGenericityGate(note.text, note, { evidenceBacked: true }),
    );
  if (backed.length === 0) return null;

  const diverse = filterCallbacksByModeDiversity(backed, entries);
  const ranked = rankCallbacksByTuning(diverse, entries).filter(
    (row) => !shouldSuppressResurfacingNote(row.note.id),
  );
  const best = ranked.find(
    (row) =>
      row.score.total >= minTotal &&
      row.score.penalties < 24 &&
      !isGenericResurfacing(row.note.text) &&
      !isTopicRecurrenceCopy(row.note.text) &&
      !isBlockedResurfacingCopy(row.note.text) &&
      !LOW_CONTRAST_RESURFACE_RE.test(row.note.id) &&
      !(isRevisitQualityNote(row.note) && shouldSuppressRevisitQuality(row.note, entries)) &&
      !shouldSuppressResurfacingConfidence(row.note, entries) &&
      !shouldSuppressResurfacingTiming(row.note, entries),
  );
  return best?.note ?? null;
}

export function applyTuningScoreBoost(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  const tuning = scoreCallbackTuning(note, entries);
  const tuned = baseScore + Math.round(tuning.total * 0.35) - tuning.penalties;
  const withLoops = applyLoopOptimizationBoost(note, entries, tuned);
  const withQuality = applyRevisitQualityRankAdjustment(note, entries, withLoops);
  const withConfidence = applyResurfacingConfidenceRankAdjustment(note, entries, withQuality);
  const withTiming = applyResurfacingTimingRankAdjustment(note, entries, withConfidence);
  const withBehavior = applyBehavioralRankingBoost(note, entries, withTiming);
  return applyCallbackLearningRankAdjustment(note, entries, withBehavior);
}

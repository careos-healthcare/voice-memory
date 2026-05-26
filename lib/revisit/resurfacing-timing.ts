import {
  callbackInteractionSignals,
  readCallbackRetention,
  summarizeCallbackRetention,
} from "@/lib/callback-interaction-signals";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { detectRevisitFatigue } from "@/lib/refinement/revisit-sequencing";
import { quoteSimilarity } from "@/lib/refinement/then-vs-now-quotes";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  assessResurfacingConfidence,
  collectResurfacingConfidenceCandidates,
  CONFIDENCE_STRONG_MIN,
} from "@/lib/revisit/resurfacing-confidence";
import {
  assessRevisitQuality,
  isRevisitQualityNote,
  REVISIT_QUALITY_MEANINGFUL_MIN,
} from "@/lib/revisit/revisit-quality";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  ResurfacingTimingClass,
  ResurfacingTimingVerdict,
} from "@/types/resurfacing-timing";

export const TIMING_MIN_EMOTIONAL_DISTANCE_DAYS = 3;
export const TIMING_SAME_DAY_STRONG_PHRASE_MIN = 72;
export const TIMING_NOVELTY_COOLDOWN_HOURS = 48;
export const TIMING_REPEATED_CALLBACK_COOLDOWN_DAYS = 5;
export const TIMING_FRESHNESS_DECAY_DAYS = 21;
export const TIMING_LONG_GAP_BOOST_DAYS = 14;
export const TIMING_SILENCE_GAP_DAYS = 7;

const EMOTIONAL_TIMING_KEY = "voicememory_emotional_timing";
const MS_PER_HOUR = 60 * 60 * 1000;

const UNUSUAL_WORDING_RE =
  /\b(i guess|sort of|maybe|probably|not sure|i keep|same loop|circling|i'm not|i am not)\b/i;

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function textKey(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 72);
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readEmotionalShownRecords(): Array<{ textKey: string; shownAt: number }> {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(EMOTIONAL_TIMING_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as { records?: Array<{ textKey: string; shownAt: number }> };
    return Array.isArray(parsed.records) ? parsed.records : [];
  } catch {
    return [];
  }
}

function hoursSinceSimilarTextShown(text: string): number | null {
  const key = textKey(text);
  const records = readEmotionalShownRecords().filter((row) => row.textKey === key);
  if (records.length === 0) return null;
  const latest = Math.max(...records.map((row) => row.shownAt));
  return (Date.now() - latest) / MS_PER_HOUR;
}

function daysSinceLastSurfaced(callbackId: string): number | null {
  const records = readCallbackRetention(callbackId).filter((row) => row.outcome === "surfaced");
  if (records.length === 0) return null;
  const latest = records.reduce((max, row) => Math.max(max, new Date(row.at).getTime()), 0);
  return daysBetweenKeys(toDayKey(new Date(latest).toISOString()), toDayKey(new Date().toISOString()));
}

function surfacedCount(callbackId: string): number {
  return readCallbackRetention(callbackId).filter((row) => row.outcome === "surfaced").length;
}

function hasQuietStretchBetween(
  past: JournalEntry,
  current: JournalEntry,
  entries: JournalEntry[],
): boolean {
  const pastMs = new Date(past.createdAt).getTime();
  const currentMs = new Date(current.createdAt).getTime();
  const between = entries.filter((entry) => {
    const ms = new Date(entry.createdAt).getTime();
    return ms > pastMs && ms < currentMs;
  });
  return between.length === 0 || between.length <= 1;
}

function scorePhraseStrength(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  let score = 0;

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    const sim = quoteSimilarity(note.pastQuote, note.currentQuote);
    if (sim >= 0.45) score += 42;
    else if (sim >= 0.28) score += 26;
  }

  if (past && current) {
    for (const record of buildPhraseMemory(entries)) {
      if (record.count < 2) continue;
      if (!record.entryIds.includes(past.id) || !record.entryIds.includes(current.id)) continue;
      score += 30 + Math.min(record.count * 4, 16);
      if (record.phrase.length >= 14 || UNUSUAL_WORDING_RE.test(record.phrase)) score += 14;
    }
  }

  if (/phrase|knows-me-phrase/i.test(note.id)) score += 22;
  return Math.min(score, 100);
}

function isUnusuallyStrongPhrase(note: MemoryNote, entries: JournalEntry[]): boolean {
  return scorePhraseStrength(note, entries) >= TIMING_SAME_DAY_STRONG_PHRASE_MIN;
}

function alreadyProcessedAfterCallback(note: MemoryNote, entries: JournalEntry[]): boolean {
  const entryIds = linkedEntriesForNote(note, entries).map((row) => row.id);
  const retention = summarizeCallbackRetention(note.id, entryIds);
  const signals = callbackInteractionSignals(note.id, entryIds);

  const engaged =
    retention.revisit > 0 ||
    retention.reread > 0 ||
    retention.recording > 0 ||
    retention.bookmark > 0 ||
    retention.copied > 0 ||
    signals.followupContinued;

  return engaged && retention.surfaced > 0;
}

function computeNextEligibleAt(
  suppressReasons: string[],
  note: MemoryNote,
  entries: JournalEntry[],
  hoursSinceSimilar: number | null,
  daysSinceSurfaced: number | null,
): string | null {
  const now = Date.now();
  let candidate: number | null = null;

  if (suppressReasons.includes("novelty_cooldown") && hoursSinceSimilar !== null) {
    const until = now + (TIMING_NOVELTY_COOLDOWN_HOURS - hoursSinceSimilar) * MS_PER_HOUR;
    candidate = Math.max(candidate ?? 0, until);
  }

  if (suppressReasons.includes("repeated_callback_cooldown") && daysSinceSurfaced !== null) {
    const until =
      now + (TIMING_REPEATED_CALLBACK_COOLDOWN_DAYS - daysSinceSurfaced) * 24 * MS_PER_HOUR;
    candidate = Math.max(candidate ?? 0, until);
  }

  if (
    suppressReasons.includes("minimum_emotional_distance") ||
    suppressReasons.includes("same_day")
  ) {
    const past = entryById(entries, note.pastEntryId);
    if (past) {
      const until = new Date(past.createdAt).getTime() + TIMING_MIN_EMOTIONAL_DISTANCE_DAYS * 86400000;
      candidate = Math.max(candidate ?? 0, until);
    }
  }

  if (suppressReasons.includes("revisit_fatigue")) {
    candidate = Math.max(candidate ?? 0, now + 3 * 86400000);
  }

  return candidate ? new Date(candidate).toISOString() : null;
}

function classifyTiming(
  timingEligible: boolean,
  timingScore: number,
  suppressReasons: string[],
): ResurfacingTimingClass {
  if (!timingEligible) {
    if (
      suppressReasons.includes("minimum_emotional_distance") ||
      suppressReasons.includes("same_day")
    ) {
      return "too_early";
    }
    return "cooling_down";
  }
  if (timingScore >= 70) return "strong_timing";
  return "eligible";
}

/** Assess whether a callback is well-timed to surface — internal only. */
export function assessResurfacingTiming(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingTimingVerdict {
  const text = note.text.trim();
  const gapDays = gapDaysForNote(note, entries);
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  const strongPhrase = isUnusuallyStrongPhrase(note, entries);
  const hoursSinceSimilar = hoursSinceSimilarTextShown(text);
  const daysSinceSurfaced = daysSinceLastSurfaced(note.id);
  const fatigue = detectRevisitFatigue();

  const reasons: string[] = [];
  const suppressReasons: string[] = [];
  let timingScore = 52;

  if (gapDays >= TIMING_LONG_GAP_BOOST_DAYS) {
    timingScore += 16;
    reasons.push("long_gap");
  }
  if (gapDays >= TIMING_MIN_EMOTIONAL_DISTANCE_DAYS) {
    timingScore += 8;
    reasons.push("emotional_distance");
  }

  const confidence = isRevisitQualityNote(note) || note.id.includes("resurface")
    ? assessResurfacingConfidence(note, entries)
    : null;

  if (confidence && confidence.totalConfidence >= CONFIDENCE_STRONG_MIN) {
    timingScore += 10;
    reasons.push("strong_confidence");
  }

  if (past && current && gapDays >= TIMING_SILENCE_GAP_DAYS && hasQuietStretchBetween(past, current, entries)) {
    const quality = isRevisitQualityNote(note)
      ? assessRevisitQuality(note, entries)
      : null;
    if (
      quality &&
      !quality.suppressed &&
      quality.total >= REVISIT_QUALITY_MEANINGFUL_MIN
    ) {
      timingScore += 14;
      reasons.push("silence_gap_high_quality");
    }
  }

  if (gapDays <= 0 && !strongPhrase) {
    suppressReasons.push("same_day");
    timingScore -= 28;
  } else if (gapDays < TIMING_MIN_EMOTIONAL_DISTANCE_DAYS && !strongPhrase) {
    suppressReasons.push("minimum_emotional_distance");
    timingScore -= 22;
  } else if (strongPhrase && gapDays <= 0) {
    reasons.push("strong_phrase_same_day");
    timingScore += 8;
  }

  if (hoursSinceSimilar !== null && hoursSinceSimilar < TIMING_NOVELTY_COOLDOWN_HOURS) {
    suppressReasons.push("novelty_cooldown");
    timingScore -= 18;
  }

  if (
    daysSinceSurfaced !== null &&
    daysSinceSurfaced < TIMING_REPEATED_CALLBACK_COOLDOWN_DAYS
  ) {
    suppressReasons.push("repeated_callback_cooldown");
    timingScore -= 20;
  }

  if (alreadyProcessedAfterCallback(note, entries)) {
    suppressReasons.push("already_processed");
    timingScore -= 24;
  }

  const priorSurfaced = surfacedCount(note.id);
  if (
    priorSurfaced >= 3 &&
    daysSinceSurfaced !== null &&
    daysSinceSurfaced < TIMING_FRESHNESS_DECAY_DAYS
  ) {
    suppressReasons.push("freshness_decay");
    timingScore -= 16;
  } else if (priorSurfaced >= 1 && daysSinceSurfaced !== null && daysSinceSurfaced >= TIMING_FRESHNESS_DECAY_DAYS) {
    reasons.push("freshness_reset");
    timingScore += 6;
  }

  if (fatigue.active && timingScore < 68 && !strongPhrase) {
    suppressReasons.push("revisit_fatigue");
    timingScore -= 12;
  }

  timingScore = Math.max(0, Math.min(100, Math.round(timingScore)));
  const timingEligible = suppressReasons.length === 0;
  const timingClass = classifyTiming(timingEligible, timingScore, suppressReasons);
  const nextEligibleAt = timingEligible
    ? null
    : computeNextEligibleAt(
        suppressReasons,
        note,
        entries,
        hoursSinceSimilar,
        daysSinceSurfaced,
      );

  return {
    noteId: note.id,
    entryId: note.entryId,
    text,
    timingEligible,
    timingScore,
    timingClass,
    reasons,
    suppressReasons,
    nextEligibleAt,
  };
}

export function shouldSuppressResurfacingTiming(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  if (!isRevisitQualityNote(note) && !note.id.includes("resurface")) {
    return false;
  }
  return !assessResurfacingTiming(note, entries).timingEligible;
}

export function isResurfacingTimingEligible(
  note: MemoryNote,
  entries: JournalEntry[],
): boolean {
  return assessResurfacingTiming(note, entries).timingEligible;
}

export function pickTimingEligibleNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
): MemoryNote[] {
  return notes.filter((note) => !shouldSuppressResurfacingTiming(note, entries));
}

export function applyResurfacingTimingRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  const verdict = assessResurfacingTiming(note, entries);
  if (!verdict.timingEligible) return baseScore - 40;
  if (verdict.timingClass === "strong_timing") return baseScore + 12;
  if (verdict.timingClass === "eligible") return baseScore + 4;
  return baseScore - 8;
}

export function collectResurfacingTimingCandidates(entries: JournalEntry[]): MemoryNote[] {
  return collectResurfacingConfidenceCandidates(entries);
}

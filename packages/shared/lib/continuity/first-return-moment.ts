import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { gateContinuityQuote } from "@/lib/continuity/continuity-quality-gate";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { toDayKey } from "@/lib/dates";
import { runCanonicalPipelineForContinuity } from "@/lib/resurfacing/canonical-resurfacing-pipeline";
import {
  buildResurfacingScores,
  mapThreadTypeToReason,
  type ResurfacingRecurrenceReason,
  type ResurfacingScoreBreakdown,
} from "@/lib/resurfacing/resurfacing-scoring";
import { phraseKeyFromQuote } from "@/lib/resurfacing/resurfacing-feedback";
import { isGenericResurfacing } from "@/lib/resurfacing/genericity-filter";
import type { ReturnThread } from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

const MIN_QUALITY_ENTRIES = 2;
const MIN_APPEARANCES = 2;
const QUOTE_MAX = 72;

export interface FirstReturnMomentData {
  quote: string;
  subline: string;
  meta: string;
  whySurfaced: string;
  recurrenceReason: ResurfacingRecurrenceReason;
  uncertain: boolean;
  relatedEntryIds: string[];
  confidence: number;
  scores: ResurfacingScoreBreakdown;
  phraseKey: string;
}

function qualityEntries(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter(isPrimarySurfacedReflection);
}

function weekdayLong(iso: string): string {
  return new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(new Date(iso));
}

function formatDisplayQuote(raw: string): string {
  const trimmed = raw.trim().slice(0, QUOTE_MAX);
  if (!trimmed) return "";
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed;
  }
  return `"${trimmed}"`;
}

function sublineForThread(thread: ReturnThread): string {
  const today = toDayKey(new Date().toISOString());
  const lastDay = toDayKey(thread.lastSeenAt);
  if (lastDay === today || (thread.gapDays ?? 0) <= 0) {
    return "You said this again today.";
  }
  if ((thread.gapDays ?? 0) <= 2) {
    return "You mentioned this again.";
  }
  return "This returned.";
}

function metaForThread(thread: ReturnThread): string {
  return `First said ${weekdayLong(thread.firstSeenAt)}`;
}

function momentFromThread(
  thread: ReturnThread,
  entries: JournalEntry[],
): FirstReturnMomentData | null {
  const quoteRaw =
    thread.contextLabel?.trim() ||
    gateContinuityQuote(thread.latestQuote) ||
    gateContinuityQuote(thread.anchorQuote) ||
    "";
  const gated = gateContinuityQuote(quoteRaw);
  if (!gated || thread.appearances < MIN_APPEARANCES) return null;

  const quote = formatDisplayQuote(gated);
  if (quote.length < 6) return null;

  const scores = buildResurfacingScores({
    quote: gated,
    appearances: thread.appearances,
    gapDays: thread.gapDays,
    threadType: thread.type,
  });

  const pipeline = runCanonicalPipelineForContinuity({
    quote: gated,
    appearances: thread.appearances,
    gapDays: thread.gapDays,
    threadType: thread.type,
    entries,
    relatedEntryIds: thread.relatedEntryIds.slice(0, 4),
  });
  if (!pipeline.show) return null;

  const reason = mapThreadTypeToReason(thread.type);
  const uncertain =
    pipeline.safeDisplayMode === "cautious" ||
    pipeline.evidence.cautiousWordingRequired;

  return {
    quote,
    subline: sublineForThread(thread),
    meta: metaForThread(thread),
    whySurfaced: pipeline.whySurfacedLines[0] ?? "",
    recurrenceReason: reason,
    uncertain,
    relatedEntryIds: thread.relatedEntryIds.slice(0, 4),
    confidence: pipeline.finalConfidence,
    scores,
    phraseKey: phraseKeyFromQuote(gated),
  };
}

function momentFromPhraseMemory(
  entries: JournalEntry[],
): FirstReturnMomentData | null {
  for (const record of buildPhraseMemory(entries)) {
    if (record.count < MIN_APPEARANCES || record.entryIds.length < MIN_QUALITY_ENTRIES) {
      continue;
    }
    const gated = gateContinuityQuote(record.phrase);
    if (!gated || gated.length < 4) continue;
    const quote = formatDisplayQuote(gated);

    const scores = buildResurfacingScores({
      quote: gated,
      appearances: record.count,
    });

    const pipeline = runCanonicalPipelineForContinuity({
      quote: gated,
      appearances: record.count,
      entries,
      relatedEntryIds: record.entryIds.slice(0, 4),
    });
    if (!pipeline.show) continue;

    const first = record.firstSeen;
    const last = record.lastSeen;
    const today = toDayKey(new Date().toISOString());
    const subline =
      toDayKey(last) === today ? "You said this again today." : "You mentioned this again.";
    const uncertain =
      pipeline.safeDisplayMode === "cautious" ||
      pipeline.evidence.cautiousWordingRequired;

    return {
      quote,
      subline,
      meta: `First said ${weekdayLong(first)}`,
      whySurfaced: pipeline.whySurfacedLines[0] ?? "",
      recurrenceReason: "phrase_memory",
      uncertain,
      relatedEntryIds: record.entryIds.slice(0, 4),
      confidence: pipeline.finalConfidence,
      scores,
      phraseKey: phraseKeyFromQuote(gated),
    };
  }
  return null;
}

/** Strongest real recurrence — null when confidence or quote quality fails. */
export function pickFirstReturnMoment(entries: JournalEntry[]): FirstReturnMomentData | null {
  const quality = qualityEntries(entries);
  if (quality.length < MIN_QUALITY_ENTRIES) return null;

  const { threads } = buildReturnThreads(quality);
  const candidates: FirstReturnMomentData[] = [];

  for (const thread of threads) {
    const moment = momentFromThread(thread, quality);
    if (moment) candidates.push(moment);
  }

  const phraseMoment = momentFromPhraseMemory(quality);
  if (phraseMoment) candidates.push(phraseMoment);

  if (candidates.length === 0) {
    void import("@/lib/resurfacing/resurfacing-metrics").then((mod) => {
      mod.recordResurfacingMetric("low_confidence_suppressed");
    });
    return null;
  }

  candidates.sort((a, b) => b.confidence - a.confidence);
  const best = candidates[0] ?? null;
  if (!best) return null;

  void import("@/lib/resurfacing/resurfacing-metrics").then((mod) => {
    mod.recordResurfacingMetric("callback_shown", { confidence: best.confidence });
    if (isGenericResurfacing(best.quote.replace(/"/g, ""))) {
      mod.recordResurfacingMetric("generic_phrase_shown");
    } else {
      mod.recordResurfacingMetric("quote_backed_shown");
    }
  });

  return best;
}

import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { gateContinuityQuote } from "@/lib/continuity/continuity-quality-gate";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { toDayKey } from "@/lib/dates";
import type { ReturnThread } from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

const MIN_QUALITY_ENTRIES = 2;
const MIN_APPEARANCES = 2;
const MIN_SCORE = 60;
const QUOTE_MAX = 72;

export interface FirstReturnMomentData {
  quote: string;
  subline: string;
  meta: string;
  relatedEntryIds: string[];
  confidence: number;
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

function scoreThread(thread: ReturnThread): number {
  const quoteRaw =
    thread.contextLabel?.trim() ||
    gateContinuityQuote(thread.latestQuote) ||
    gateContinuityQuote(thread.anchorQuote) ||
    "";
  const quote = gateContinuityQuote(quoteRaw) ?? "";
  if (!quote || quote.length < 4) return 0;
  if (thread.appearances < MIN_APPEARANCES) return 0;

  let score = 45 + thread.appearances * 8;
  if (thread.type === "repeated_phrase") score += 14;
  if (thread.type === "recurring_person") score += 10;
  if (thread.type === "recurring_uncertainty") score += 8;
  if ((thread.gapDays ?? 0) >= 1 && (thread.gapDays ?? 0) <= 21) score += 6;
  return score;
}

function momentFromThread(thread: ReturnThread): FirstReturnMomentData | null {
  const score = scoreThread(thread);
  if (score < MIN_SCORE) return null;

  const quoteRaw =
    thread.contextLabel?.trim() ||
    gateContinuityQuote(thread.latestQuote) ||
    gateContinuityQuote(thread.anchorQuote) ||
    "";
  const gated = gateContinuityQuote(quoteRaw);
  if (!gated) return null;

  const quote = formatDisplayQuote(gated);
  if (quote.length < 6) return null;

  return {
    quote,
    subline: sublineForThread(thread),
    meta: metaForThread(thread),
    relatedEntryIds: thread.relatedEntryIds.slice(0, 4),
    confidence: Math.min(100, score),
  };
}

function momentFromPhraseMemory(entries: JournalEntry[]): FirstReturnMomentData | null {
  for (const record of buildPhraseMemory(entries)) {
    if (record.count < MIN_APPEARANCES || record.entryIds.length < MIN_QUALITY_ENTRIES) {
      continue;
    }
    const gated = gateContinuityQuote(record.phrase);
    if (!gated || gated.length < 4) continue;
    const quote = formatDisplayQuote(gated);
    const first = record.firstSeen;
    const last = record.lastSeen;
    const today = toDayKey(new Date().toISOString());
    const subline =
      toDayKey(last) === today ? "You said this again today." : "You mentioned this again.";
    return {
      quote,
      subline,
      meta: `First said ${weekdayLong(first)}`,
      relatedEntryIds: record.entryIds.slice(0, 4),
      confidence: 58 + record.count * 4,
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
    const moment = momentFromThread(thread);
    if (moment) candidates.push(moment);
  }

  const phraseMoment = momentFromPhraseMemory(quality);
  if (phraseMoment) candidates.push(phraseMoment);

  if (candidates.length === 0) return null;

  candidates.sort((a, b) => b.confidence - a.confidence);
  return candidates[0] ?? null;
}

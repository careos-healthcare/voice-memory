import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import type { JournalEntry } from "@/types/journal";
import type { LifePeriod, LifePeriodKind, LifePeriodReport } from "@/types/archive-permanence-layer";
import type { MemoryNote } from "@/types/memory-note";

export const LIFE_PERIOD_COPY: Record<LifePeriodKind, string> = {
  moving: "You were still living differently here.",
  relationships_changing: "This belonged to a heavier stretch.",
  grief_loss: "This belonged to a heavier stretch.",
  burnout: "This belonged to a heavier stretch.",
  career_shift: "This was before things settled down.",
  recovery: "This was before things settled down.",
  uncertainty: "You kept returning to this around that time.",
  quieter_season: "This was before things settled down.",
};

export const LIFE_PERIOD_FORBIDDEN = [
  "phase 1",
  "growth era",
  "healing journey",
  "psychological",
  "diagnostic",
  "trauma",
  "inner child",
] as const;

const MIN_PERIOD_ENTRIES = 3;
const MIN_PERIOD_DAYS = 21;

const MOVING_RE = /\b(move|moving|moved|apartment|house|city|relocate|lease)\b/i;
const RELATIONSHIP_RE = /\b(breakup|relationship|partner|married|divorce|together|apart|left me|left him|left her)\b/i;
const BURNOUT_RE = /\b(burned out|burnt out|exhausted|overwhelmed|too much|can't keep|running on empty)\b/i;
const GRIEF_RE = /\b(grief|loss|died|death|funeral|miss them|missing|gone)\b/i;
const CAREER_RE = /\b(job|work|career|promotion|quit|resigned|fired|laid off|new role|office)\b/i;
const RECOVERY_RE = /\b(recover|recovery|rest|resting|slowing down|easing|better now|coming back)\b/i;
const UNCERTAINTY_RE = /\b(not sure|unclear|uncertain|worried|anxious|maybe|don't know)\b/i;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function snippet(entry: JournalEntry): string {
  return (
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim() ||
    entry.transcript.trim()
  ).slice(0, 200);
}

function passesLifePeriodCopy(text: string): boolean {
  const lower = text.toLowerCase();
  if (LIFE_PERIOD_FORBIDDEN.some((phrase) => lower.includes(phrase))) return false;
  return helpsOrient(text, 60);
}

function detectKindInWindow(window: JournalEntry[]): LifePeriodKind | null {
  const text = window.map(snippet).join(" ").toLowerCase();
  const scores: Array<{ kind: LifePeriodKind; score: number }> = [
    { kind: "moving", score: (text.match(MOVING_RE) ?? []).length * 3 },
    { kind: "relationships_changing", score: (text.match(RELATIONSHIP_RE) ?? []).length * 3 },
    { kind: "burnout", score: (text.match(BURNOUT_RE) ?? []).length * 3 },
    { kind: "grief_loss", score: (text.match(GRIEF_RE) ?? []).length * 4 },
    { kind: "career_shift", score: (text.match(CAREER_RE) ?? []).length * 2 },
    { kind: "recovery", score: (text.match(RECOVERY_RE) ?? []).length * 2 },
    { kind: "uncertainty", score: (text.match(UNCERTAINTY_RE) ?? []).length * 2 },
  ];

  const avgIntensity =
    window.reduce((sum, e) => sum + e.reflection.emotionalIntensity, 0) / window.length;

  if (avgIntensity <= 4.2 && window.length >= 4) {
    scores.push({ kind: "quieter_season", score: 4 });
  }

  const best = scores.sort((a, b) => b.score - a.score)[0];
  return best && best.score >= 3 ? best.kind : null;
}

function buildWindows(entries: JournalEntry[], windowDays = 45): JournalEntry[][] {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_PERIOD_ENTRIES) return [];

  const windows: JournalEntry[][] = [];
  let start = 0;

  while (start < sorted.length) {
    const anchor = sorted[start];
    const window: JournalEntry[] = [anchor];
    for (let i = start + 1; i < sorted.length; i += 1) {
      const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(sorted[i].createdAt));
      if (gap > windowDays) break;
      window.push(sorted[i]);
    }
    if (window.length >= MIN_PERIOD_ENTRIES) windows.push(window);
    start += Math.max(1, Math.floor(window.length / 2));
  }

  return windows;
}

/** Detect broad life periods from archive entries — grounded temporal copy only. */
export function buildLifePeriodReport(entries: JournalEntry[]): LifePeriodReport {
  const windows = buildWindows(entries);
  const periods: LifePeriod[] = [];
  const seen = new Set<string>();

  for (const window of windows) {
    const kind = detectKindInWindow(window);
    if (!kind) continue;

    const startAt = window[0].createdAt;
    const endAt = window[window.length - 1].createdAt;
    const spanDays = daysBetweenKeys(toDayKey(startAt), toDayKey(endAt));
    if (spanDays < MIN_PERIOD_DAYS && window.length < 4) continue;

    const key = `${kind}:${startAt.slice(0, 7)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const text = LIFE_PERIOD_COPY[kind];
    if (!passesLifePeriodCopy(text)) continue;

    periods.push({
      id: `life-period-${kind}-${startAt.slice(0, 10)}`,
      kind,
      text,
      startAt,
      endAt,
      entryIds: window.map((e) => e.id),
      strength: Math.min(88, 60 + window.length * 3 + Math.min(spanDays / 7, 8)),
    });
  }

  periods.sort((a, b) => b.strength - a.strength);

  return {
    generatedAt: new Date().toISOString(),
    hasData: periods.length > 0,
    periods: periods.slice(0, 8),
  };
}

export function lifePeriodToNote(period: LifePeriod): MemoryNote {
  return {
    id: period.id,
    text: period.text,
    category: "returned",
    confidence: period.strength,
    entryId: period.entryIds[period.entryIds.length - 1],
  };
}

/** Pick one sparse life-period note for archive surfaces. */
export function pickPrimaryLifePeriod(
  entries: JournalEntry[],
): MemoryNote | null {
  const report = buildLifePeriodReport(entries);
  const period = report.periods[0];
  if (!period) return null;
  return lifePeriodToNote(period);
}

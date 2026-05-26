import { buildEntityMemoryFromEntries, type EntityType } from "@/lib/entity-memory";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import type { JournalEntry } from "@/types/journal";

const MIN_PHRASE_LEN = 14;
const MIN_PHRASE_COUNT = 2;
const MIN_PHRASE_GAP_DAYS = 2;
const MIN_CONCERN_OVERLAP = 0.35;
const MIN_ENTITY_ENTRIES = 2;
const MIN_MOOD_SHIFT_INTENSITY = 1.2;

export interface RepeatedPhraseSignal {
  phrase: string;
  count: number;
  entryIds: string[];
  gapDays: number;
}

export interface RepeatedConcernSignal {
  concern: string;
  entryIds: string[];
}

export interface NamedEntitySignal {
  name: string;
  type: EntityType;
  entryIds: string[];
}

export interface RepeatedThemeReport {
  phrases: RepeatedPhraseSignal[];
  concerns: RepeatedConcernSignal[];
  entities: NamedEntitySignal[];
  moodShifts: Array<{ entryIds: [string, string]; gapDays: number }>;
}

function tokenOverlap(a: string, b: string): number {
  const left = new Set(a.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  const right = new Set(b.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
}

/** Conservative repeated-theme scan — ignores loose token overlap. */
export function buildRepeatedThemeReport(entries: JournalEntry[]): RepeatedThemeReport {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  const phrases: RepeatedPhraseSignal[] = [];
  for (const record of buildPhraseMemory(sorted)) {
    if (record.count < MIN_PHRASE_COUNT) continue;
    if (record.phrase.length < MIN_PHRASE_LEN) continue;
    const ids = record.entryIds;
    if (ids.length < 2) continue;
    const first = sorted.find((e) => e.id === ids[0]);
    const last = sorted.find((e) => e.id === ids[ids.length - 1]);
    const gapDays =
      first && last
        ? daysBetweenKeys(toDayKey(first.createdAt), toDayKey(last.createdAt))
        : 0;
    if (gapDays < MIN_PHRASE_GAP_DAYS) continue;
    phrases.push({
      phrase: record.phrase,
      count: record.count,
      entryIds: ids,
      gapDays,
    });
  }

  const concerns: RepeatedConcernSignal[] = [];
  const concernRows = sorted.filter((e) => e.reflection.hiddenConcern?.trim());
  for (let i = 0; i < concernRows.length; i += 1) {
    for (let j = i + 1; j < concernRows.length; j += 1) {
      const left = concernRows[i].reflection.hiddenConcern!.trim();
      const right = concernRows[j].reflection.hiddenConcern!.trim();
      if (left === right || tokenOverlap(left, right) >= MIN_CONCERN_OVERLAP) {
        concerns.push({
          concern: left,
          entryIds: [concernRows[i].id, concernRows[j].id],
        });
        break;
      }
    }
  }

  const entityReport = buildEntityMemoryFromEntries(sorted);
  const entities: NamedEntitySignal[] = [];
  for (const row of [
    ...entityReport.people,
    ...entityReport.concerns,
    ...entityReport.topics,
    ...entityReport.goals,
  ]) {
    if (row.entryIds.length < MIN_ENTITY_ENTRIES) continue;
    if (row.name.length < 3) continue;
    entities.push({
      name: row.name,
      type: row.type,
      entryIds: row.entryIds,
    });
  }

  const moodShifts: RepeatedThemeReport["moodShifts"] = [];
  for (let i = 0; i < sorted.length; i += 1) {
    for (let j = i + 1; j < sorted.length; j += 1) {
      const a = sorted[i];
      const b = sorted[j];
      const gapDays = daysBetweenKeys(toDayKey(a.createdAt), toDayKey(b.createdAt));
      if (gapDays < MIN_PHRASE_GAP_DAYS) continue;
      const intensityDelta = Math.abs(
        a.reflection.emotionalIntensity - b.reflection.emotionalIntensity,
      );
      const moodChanged = a.reflection.mood !== b.reflection.mood;
      if (moodChanged && intensityDelta >= MIN_MOOD_SHIFT_INTENSITY) {
        moodShifts.push({ entryIds: [a.id, b.id], gapDays });
      }
    }
  }

  return {
    phrases: phrases.slice(0, 8),
    concerns: concerns.slice(0, 6),
    entities: entities.slice(0, 8),
    moodShifts: moodShifts.slice(0, 6),
  };
}

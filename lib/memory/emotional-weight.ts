import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import type {
  ContinuityCallback,
  ContinuityCallbackKind,
  ContinuityMoment,
  ContinuityMomentKind,
  ThenVsNowComparison,
} from "@/types/continuity-moments";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { RevisitationKind } from "@/types/revisitation";

/** Internal floor — never shown in UI. */
export const EMOTIONAL_WEIGHT_MIN = 58;
export const EMOTIONAL_WEIGHT_STRONG = 68;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|i don't know|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|i know|decided|named|wrote down|clearly|for sure|definitely|mum|dad|mother|father)\b/gi;

export interface EmotionalWeightSignals {
  intensity?: number;
  recurrence?: number;
  contradiction?: number;
  silenceGapDays?: number;
  directNaming?: number;
  hedgeReduction?: number;
  recoveryAfterPressure?: number;
  languageUniqueness?: number;
  revisitationRelevance?: number;
}

export interface WeightedSelectionOptions {
  limit: number;
  minWeight?: number;
  strongExtra?: boolean;
  strongThreshold?: number;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function entryById(sorted: JournalEntry[], id: string): JournalEntry | undefined {
  return sorted.find((entry) => entry.id === id);
}

function entriesForIds(sorted: JournalEntry[], ids: string[]): JournalEntry[] {
  return ids
    .map((id) => entryById(sorted, id))
    .filter((entry): entry is JournalEntry => Boolean(entry));
}

/** Combine continuity signals into a single internal weight score. */
export function computeEmotionalWeight(signals: EmotionalWeightSignals): number {
  let weight = 48;

  if (signals.intensity !== undefined) {
    weight += Math.min(Math.max(signals.intensity, 0) * 2.2, 16);
  }
  if (signals.recurrence !== undefined) {
    weight += Math.min(Math.max(signals.recurrence, 0) * 2.5, 12);
  }
  if (signals.contradiction !== undefined) {
    weight += Math.min(Math.max(signals.contradiction, 0) * 8, 12);
  }
  if (signals.silenceGapDays !== undefined) {
    weight += Math.min(Math.max(signals.silenceGapDays, 0) * 0.35, 14);
  }
  if (signals.directNaming !== undefined) {
    weight += Math.min(Math.max(signals.directNaming, 0) * 4, 12);
  }
  if (signals.hedgeReduction !== undefined) {
    weight += Math.min(Math.max(signals.hedgeReduction, 0) * 5, 12);
  }
  if (signals.recoveryAfterPressure !== undefined) {
    weight += Math.min(Math.max(signals.recoveryAfterPressure, 0) * 5, 14);
  }
  if (signals.languageUniqueness !== undefined) {
    weight += Math.min(Math.max(signals.languageUniqueness, 0) * 4, 10);
  }
  if (signals.revisitationRelevance !== undefined) {
    weight += Math.min(Math.max(signals.revisitationRelevance, 0) * 4, 12);
  }

  return Math.round(Math.min(100, weight));
}

export function rankByEmotionalWeight<T>(
  items: T[],
  weightOf: (item: T) => number,
  limit: number,
  minWeight = EMOTIONAL_WEIGHT_MIN,
): T[] {
  return items
    .map((item) => ({ item, weight: weightOf(item) }))
    .filter(({ weight }) => weight >= minWeight)
    .sort((a, b) => b.weight - a.weight)
    .slice(0, limit)
    .map(({ item }) => item);
}

/** Prefer fewer stronger memories; allow one extra only when weight is high. */
export function pickStrongestByWeight<T>(
  items: T[],
  weightOf: (item: T) => number,
  max: number,
  minWeight = EMOTIONAL_WEIGHT_MIN,
  strongThreshold = EMOTIONAL_WEIGHT_STRONG,
): T[] {
  const ranked = rankByEmotionalWeight(items, weightOf, items.length, minWeight);
  if (ranked.length === 0) return [];
  if (ranked.length <= Math.max(1, max - 1)) return ranked.slice(0, max);

  const base = ranked.slice(0, Math.max(1, max - 1));
  if (ranked.length >= max && weightOf(ranked[max - 1]) >= strongThreshold) {
    return ranked.slice(0, max);
  }
  return base;
}

export function suppressLowWeight<T>(
  items: T[],
  weightOf: (item: T) => number,
  minWeight = EMOTIONAL_WEIGHT_MIN,
): T[] {
  return items.filter((item) => weightOf(item) >= minWeight);
}

function callbackKindBoost(kind: ContinuityCallbackKind): Partial<EmotionalWeightSignals> {
  switch (kind) {
    case "first_direct":
      return { directNaming: 3, contradiction: 0.5 };
    case "used_to_be_vague":
      return { hedgeReduction: 2, directNaming: 1 };
    case "sounds_calmer":
      return { recoveryAfterPressure: 2 };
    case "sounds_different":
      return { contradiction: 1, recoveryAfterPressure: 1 };
    case "came_up_differently":
      return { contradiction: 0.8, recurrence: 1 };
    case "topic_stopped":
      return { silenceGapDays: 14, recurrence: 1 };
  }
}

function momentKindBoost(kind: ContinuityMomentKind): Partial<EmotionalWeightSignals> {
  switch (kind) {
    case "first_calmer_mention":
      return { recoveryAfterPressure: 2.5, directNaming: 0.5 };
    case "first_direct_mention":
      return { directNaming: 3, hedgeReduction: 1 };
    case "recovery_after_spike":
      return { recoveryAfterPressure: 3, contradiction: 0.5 };
    case "last_concern_appearance":
      return { intensity: 2, contradiction: 0.5 };
    case "phrase_disappearance":
      return { silenceGapDays: 10, languageUniqueness: 1 };
    case "topic_resolved":
      return { recoveryAfterPressure: 1.5 };
    case "loop_returning":
      return { silenceGapDays: 12, recurrence: 2 };
  }
}

export function weightEntryReflection(
  entry: JournalEntry,
  sorted: JournalEntry[],
): number {
  const idx = sorted.findIndex((item) => item.id === entry.id);
  const prior = idx > 0 ? sorted.slice(0, idx) : sorted.filter((item) => item.id !== entry.id);

  const themeCounts = entry.reflection.recurringThemes.map((theme) => {
    const key = theme.toLowerCase();
    return prior.filter((item) =>
      item.reflection.recurringThemes.some((t) => t.toLowerCase() === key),
    ).length;
  });

  const recurrence = themeCounts.length > 0 ? Math.max(...themeCounts) : 0;
  const hasContradiction = Boolean(
    entry.reflection.tensionOrContradiction?.trim() ||
      entry.reflection.avoidedOrVagueArea?.trim(),
  );

  const phrases = buildPhraseMemory(sorted);
  const uniquePhrase = phrases.find(
    (record) => record.count <= 2 && record.entryIds.includes(entry.id),
  );

  return computeEmotionalWeight({
    intensity: entry.reflection.emotionalIntensity,
    recurrence,
    contradiction: hasContradiction ? 1 : 0,
    directNaming: countMatches(entry.transcript, DIRECT_RE),
    hedgeReduction: Math.max(
      0,
      roundAvg(prior.map((item) => countMatches(item.transcript, HEDGE_RE))) -
        countMatches(entry.transcript, HEDGE_RE),
    ),
    languageUniqueness: uniquePhrase ? 2 : 0,
  });
}

export function weightContinuityCallback(
  callback: ContinuityCallback,
  sorted: JournalEntry[],
): number {
  const entries = entriesForIds(sorted, callback.entryIds);
  const current = entries[entries.length - 1];
  const prior = entries.slice(0, -1);

  let silenceGapDays = 0;
  if (prior.length > 0 && current) {
    silenceGapDays = daysBetweenKeys(
      toDayKey(prior[prior.length - 1].createdAt),
      toDayKey(current.createdAt),
    );
  }

  const recoveryAfterPressure =
    prior.length > 0 && current
      ? roundAvg(prior.map((entry) => entry.reflection.emotionalIntensity)) -
        current.reflection.emotionalIntensity
      : 0;

  const signals: EmotionalWeightSignals = {
    intensity: current?.reflection.emotionalIntensity,
    recurrence: entries.length,
    silenceGapDays,
    recoveryAfterPressure: recoveryAfterPressure > 0 ? recoveryAfterPressure : 0,
    directNaming: current ? countMatches(current.transcript, DIRECT_RE) : 0,
    hedgeReduction:
      prior.length > 0 && current
        ? roundAvg(prior.map((entry) => countMatches(entry.transcript, HEDGE_RE))) -
          countMatches(current.transcript, HEDGE_RE)
        : 0,
    ...callbackKindBoost(callback.kind),
  };

  return Math.max(callback.confidence, computeEmotionalWeight(signals));
}

export function weightContinuityMoment(
  moment: ContinuityMoment,
  sorted: JournalEntry[],
): number {
  const entries = entriesForIds(sorted, moment.entryIds);
  const intensities = entries.map((entry) => entry.reflection.emotionalIntensity);
  const peak = intensities.length > 0 ? Math.max(...intensities) : 0;

  let silenceGapDays = 0;
  if (entries.length >= 2) {
    silenceGapDays = daysBetweenKeys(
      toDayKey(entries[0].createdAt),
      toDayKey(entries[entries.length - 1].createdAt),
    );
  }

  const signals: EmotionalWeightSignals = {
    intensity: peak,
    recurrence: entries.length,
    silenceGapDays,
    ...momentKindBoost(moment.kind),
  };

  return Math.max(moment.confidence, computeEmotionalWeight(signals));
}

export function weightThenVsNow(
  comparison: ThenVsNowComparison,
  sorted: JournalEntry[],
): number {
  const thenEntry = entryById(sorted, comparison.then.entryId);
  const nowEntry = entryById(sorted, comparison.now.entryId);
  if (!thenEntry || !nowEntry) return comparison.confidence;

  const intensityDelta =
    thenEntry.reflection.emotionalIntensity - nowEntry.reflection.emotionalIntensity;
  const hedgeDelta =
    countMatches(thenEntry.transcript, HEDGE_RE) -
    countMatches(nowEntry.transcript, HEDGE_RE);
  const directDelta =
    countMatches(nowEntry.transcript, DIRECT_RE) -
    countMatches(thenEntry.transcript, DIRECT_RE);
  const gap = daysBetweenKeys(
    toDayKey(thenEntry.createdAt),
    toDayKey(nowEntry.createdAt),
  );

  const priorThemeCount = sorted.filter((entry) =>
    entry.reflection.recurringThemes.some(
      (theme) => theme.toLowerCase() === comparison.subject.toLowerCase(),
    ),
  ).length;

  const signals: EmotionalWeightSignals = {
    intensity: Math.max(thenEntry.reflection.emotionalIntensity, nowEntry.reflection.emotionalIntensity),
    recurrence: priorThemeCount,
    silenceGapDays: gap,
    contradiction: Math.abs(intensityDelta) >= 1.5 || thenEntry.reflection.mood !== nowEntry.reflection.mood ? 1 : 0.5,
    recoveryAfterPressure: intensityDelta >= 1.5 ? intensityDelta : 0,
    hedgeReduction: hedgeDelta > 0 ? hedgeDelta : 0,
    directNaming: directDelta > 0 ? directDelta : 0,
    revisitationRelevance: gap >= 14 ? 2 : 1,
  };

  return Math.max(comparison.confidence, computeEmotionalWeight(signals));
}

export function weightMemoryNote(note: MemoryNote, sorted: JournalEntry[]): number {
  const current = note.entryId ? entryById(sorted, note.entryId) : undefined;
  const past = note.pastEntryId ? entryById(sorted, note.pastEntryId) : undefined;

  let gap = 0;
  if (current && past) {
    gap = daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
  }

  const signals: EmotionalWeightSignals = {
    intensity: current?.reflection.emotionalIntensity,
    silenceGapDays: gap,
    revisitationRelevance: note.id.includes("revisit-") ? 2 : 0,
    recoveryAfterPressure:
      current && past
        ? past.reflection.emotionalIntensity - current.reflection.emotionalIntensity
        : 0,
    directNaming: current ? countMatches(current.transcript, DIRECT_RE) : 0,
    hedgeReduction:
      current && past
        ? countMatches(past.transcript, HEDGE_RE) - countMatches(current.transcript, HEDGE_RE)
        : 0,
  };

  if (note.id.startsWith("change-")) {
    signals.contradiction = 1;
    signals.recoveryAfterPressure = Math.max(signals.recoveryAfterPressure ?? 0, 1.5);
  }
  if (note.id.includes("resurface-loop") || note.id.includes("moment-loop")) {
    signals.silenceGapDays = Math.max(gap, 14);
    signals.recurrence = 2;
  }
  if (note.id.includes("calmer") || note.id.includes("first-calm")) {
    signals.recoveryAfterPressure = Math.max(signals.recoveryAfterPressure ?? 0, 2);
  }

  return Math.max(note.confidence, computeEmotionalWeight(signals));
}

export function weightRevisitationKind(
  kind: RevisitationKind,
  strength: number,
  gapDays = 0,
): number {
  const signals: EmotionalWeightSignals = {
    silenceGapDays: gapDays,
    revisitationRelevance: 1,
  };

  switch (kind) {
    case "reads_differently":
      signals.contradiction = 1.2;
      signals.revisitationRelevance = 2.5;
      break;
    case "loop_return":
      signals.recurrence = 2;
      signals.silenceGapDays = Math.max(gapDays, 14);
      break;
    case "before_quieter":
      signals.recoveryAfterPressure = 2;
      break;
    case "related_older":
    case "worth_revisit":
    case "first_topic":
      signals.revisitationRelevance = 0.5;
      break;
  }

  return Math.max(strength, computeEmotionalWeight(signals));
}

export function weightResurfacingNote(
  baseConfidence: number,
  options: {
    gapDays?: number;
    kind?: string;
    isLoop?: boolean;
    isCalmer?: boolean;
    isContrast?: boolean;
    isDirect?: boolean;
  } = {},
): number {
  const gap = options.gapDays ?? 0;
  const signals: EmotionalWeightSignals = {
    silenceGapDays: gap,
    recurrence: options.isLoop ? 2 : 1,
  };

  if (options.isCalmer) signals.recoveryAfterPressure = 2;
  if (options.isContrast) signals.contradiction = 1;
  if (options.isDirect) signals.directNaming = 2;
  if (options.isLoop && gap >= 21) signals.silenceGapDays = gap;

  return Math.max(baseConfidence, computeEmotionalWeight(signals));
}

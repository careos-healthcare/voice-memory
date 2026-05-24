import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  hasTheme,
  languageShiftOnTheme,
} from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import type {
  EmotionalMilestone,
  EmotionalMilestoneContext,
  EmotionalMilestoneCopyExample,
  EmotionalMilestoneKind,
  EmotionalMilestoneReport,
} from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";
import { applyMilestoneHierarchy } from "@/lib/refinement/memory-hierarchy";

const MILESTONE_KEY = "voicememory_emotional_milestones";
const MIN_ENTRIES = 5;
const STRONG_MIN = 66;
const ABSENCE_DAYS = 14;
const INTENSITY_PERIOD_MIN = 6;
const TEXT_COOLDOWN_DAYS = 21;
const SURFACE_COOLDOWN_DAYS = 7;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|told|said to)\b/gi;
const LOOP_RE =
  /\b(same loop|keep coming back|again before|that loop|same pattern|i keep)\b/i;

const COPY: Record<EmotionalMilestoneKind, string> = {
  first_calmer_topic: "This was the first time it sounded calmer.",
  topic_absent_after_intensity: "It went quiet after that stretch.",
  phrase_disappeared: "It went quiet after that stretch.",
  direct_naming: "This was when you named it differently.",
  recovery_after_loop: "This was the first time it sounded calmer.",
};

export const EMOTIONAL_MILESTONE_COPY_EXAMPLES: EmotionalMilestoneCopyExample[] = [
  {
    kind: "first_calmer_topic",
    message: COPY.first_calmer_topic,
    whenShown: "A recurring topic appeared with noticeably less intensity for the first time",
  },
  {
    kind: "topic_absent_after_intensity",
    message: COPY.topic_absent_after_intensity,
    whenShown: "A topic that carried weight for a while has not returned for some time",
  },
  {
    kind: "phrase_disappeared",
    message: COPY.phrase_disappeared,
    whenShown: "A familiar phrase stopped showing up after a sustained run",
  },
  {
    kind: "direct_naming",
    message: COPY.direct_naming,
    whenShown: "Language around a topic became more direct after earlier vague references",
  },
  {
    kind: "recovery_after_loop",
    message: COPY.recovery_after_loop,
    whenShown: "A familiar loop returned with less tension than earlier passes",
  },
];

export interface EmotionalMilestoneOptions {
  context: EmotionalMilestoneContext;
  entryId?: string;
  limit?: number;
  record?: boolean;
}

interface MilestoneState {
  records: Array<{
    milestoneId: string;
    textKey: string;
    surface: EmotionalMilestoneContext;
    shownAt: number;
  }>;
}

const KIND_PRIORITY: EmotionalMilestoneKind[] = [
  "first_calmer_topic",
  "recovery_after_loop",
  "direct_naming",
  "topic_absent_after_intensity",
  "phrase_disappeared",
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function milestoneEvidence(past: JournalEntry, current: JournalEntry) {
  return {
    pastEntryId: past.id,
    entryId: current.id,
    href: `/entry/${current.id}`,
  };
}

function readState(): MilestoneState {
  if (!isBrowser()) return { records: [] };
  try {
    const raw = localStorage.getItem(MILESTONE_KEY);
    if (!raw) return { records: [] };
    const parsed = JSON.parse(raw) as MilestoneState;
    return { records: parsed.records ?? [] };
  } catch {
    return { records: [] };
  }
}

function writeState(state: MilestoneState): void {
  if (!isBrowser()) return;
  localStorage.setItem(MILESTONE_KEY, JSON.stringify(state));
}

function pushMilestone(
  bucket: EmotionalMilestone[],
  item: Omit<EmotionalMilestone, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? STRONG_MIN;
  if (strength < USEFULNESS_MIN_CONFIDENCE) return;
  const orienting =
    item.kind === "direct_naming" || helpsOrient(item.text, strength);
  if (!orienting) return;
  bucket.push({ ...item, strength });
}

function detectFirstCalmerTopics(sorted: JournalEntry[]): EmotionalMilestone[] {
  const milestones: EmotionalMilestone[] = [];
  const themePrior = new Map<string, JournalEntry[]>();
  const marked = new Set<string>();

  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const prior = themePrior.get(key) ?? [];
      if (prior.length >= 2 && !marked.has(key)) {
        const priorAvg = roundAvg(prior.map((e) => e.reflection.emotionalIntensity));
        if (entry.reflection.emotionalIntensity <= priorAvg - 1.5) {
          const lastPrior = prior[prior.length - 1];
          pushMilestone(milestones, {
            id: `milestone-first-calmer-${key}-${entry.id}`,
            kind: "first_calmer_topic",
            text: COPY.first_calmer_topic,
            subject: theme,
            strength: STRONG_MIN + 4 + Math.round(priorAvg - entry.reflection.emotionalIntensity),
            ...milestoneEvidence(lastPrior, entry),
          });
          marked.add(key);
        }
      }
      prior.push(entry);
      themePrior.set(key, prior);
    }
  }

  return milestones;
}

function detectTopicAbsentAfterIntensity(sorted: JournalEntry[]): EmotionalMilestone[] {
  const milestones: EmotionalMilestone[] = [];
  const today = toDayKey(new Date().toISOString());
  const themeHits = new Map<string, JournalEntry[]>();

  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      const list = themeHits.get(key) ?? [];
      list.push(entry);
      themeHits.set(key, list);
    }
  }

  for (const [themeKey, hits] of themeHits) {
    if (hits.length < 3) continue;

    const intenseHits = hits.filter((e) => e.reflection.emotionalIntensity >= INTENSITY_PERIOD_MIN);
    if (intenseHits.length < 2) continue;

    const last = hits[hits.length - 1];
    const gap = daysBetweenKeys(toDayKey(last.createdAt), today);
    if (gap < ABSENCE_DAYS) continue;

    const recentCutoff = addDaysToKey(today, -ABSENCE_DAYS);
    const recent = hits.filter((e) => toDayKey(e.createdAt) >= recentCutoff);
    if (recent.length > 0) continue;

    pushMilestone(milestones, {
      id: `milestone-absent-${themeKey}-${last.id}`,
      kind: "topic_absent_after_intensity",
      text: COPY.topic_absent_after_intensity,
      subject: themeKey,
      strength: STRONG_MIN + Math.min(gap, 10) + intenseHits.length,
      pastEntryId: last.id,
      entryId: last.id,
      href: `/entry/${last.id}`,
    });
  }

  return milestones;
}

function detectPhraseDisappeared(sorted: JournalEntry[]): EmotionalMilestone[] {
  const milestones: EmotionalMilestone[] = [];
  const today = toDayKey(new Date().toISOString());
  const cutoff = addDaysToKey(today, -ABSENCE_DAYS);
  const phrases = buildPhraseMemory(sorted);

  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    if (lastOcc.dateKey >= cutoff) continue;

    const gap = daysBetweenKeys(lastOcc.dateKey, today);
    if (gap < ABSENCE_DAYS) continue;

    const priorEntry = sorted.find((e) => e.id === lastOcc.entryId);
    if (!priorEntry) continue;

    pushMilestone(milestones, {
      id: `milestone-phrase-${textKey(record.phrase)}`,
      kind: "phrase_disappeared",
      text: COPY.phrase_disappeared,
      subject: record.phrase,
      strength: STRONG_MIN + Math.min(record.count, 4) + Math.min(gap, 8),
      entryId: priorEntry.id,
      href: `/entry/${priorEntry.id}`,
    });
  }

  return milestones;
}

function detectDirectNaming(sorted: JournalEntry[]): EmotionalMilestone[] {
  const milestones: EmotionalMilestone[] = [];
  const marked = new Set<string>();

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    const prior = sorted.slice(0, i);

    for (const theme of current.reflection.recurringThemes) {
      const themeKey = theme.toLowerCase();
      if (marked.has(themeKey)) continue;

      const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
      if (priorMatches.length < 2) continue;

      const vaguePrior = priorMatches.filter(
        (e) =>
          countMatches(e.transcript, HEDGE_RE) >= 2 ||
          Boolean(e.reflection.avoidedOrVagueArea?.trim()),
      );
      if (vaguePrior.length < 1) continue;

      const lastVague = vaguePrior[vaguePrior.length - 1];
      const shift = languageShiftOnTheme(lastVague, current);
      const becameDirect =
        shift.directDelta >= 1 ||
        (shift.hedgeDelta >= 2 && countMatches(current.transcript, DIRECT_RE) >= 1);

      if (!becameDirect) continue;

      pushMilestone(milestones, {
        id: `milestone-direct-${themeKey}-${current.id}`,
        kind: "direct_naming",
        text: COPY.direct_naming,
        subject: theme,
        strength: STRONG_MIN + shift.directDelta * 3 + shift.hedgeDelta,
        ...milestoneEvidence(lastVague, current),
      });
      marked.add(themeKey);
    }
  }

  return milestones;
}

function detectRecoveryAfterLoop(sorted: JournalEntry[]): EmotionalMilestone[] {
  const milestones: EmotionalMilestone[] = [];
  const marked = new Set<string>();

  for (let i = 2; i < sorted.length; i += 1) {
    const current = sorted[i];
    const prior = sorted.slice(0, i);

    for (const theme of current.reflection.recurringThemes) {
      const themeKey = theme.toLowerCase();
      if (marked.has(themeKey)) continue;

      const priorLoop = prior.filter(
        (e) => hasTheme(e, themeKey) && LOOP_RE.test(e.transcript),
      );
      if (priorLoop.length < 2) continue;

      const loopPrior = priorLoop[priorLoop.length - 1];
      if (
        current.reflection.emotionalIntensity >
        loopPrior.reflection.emotionalIntensity - 1
      ) {
        continue;
      }

      pushMilestone(milestones, {
        id: `milestone-recovery-${themeKey}-${current.id}`,
        kind: "recovery_after_loop",
        text: COPY.recovery_after_loop,
        subject: theme,
        strength: STRONG_MIN + priorLoop.length + 2,
        pastEntryId: loopPrior.id,
        entryId: current.id,
        href: `/entry/${current.id}`,
      });
      marked.add(themeKey);
    }
  }

  return milestones;
}

function detectAllMilestones(sorted: JournalEntry[]): EmotionalMilestone[] {
  return [
    ...detectFirstCalmerTopics(sorted),
    ...detectTopicAbsentAfterIntensity(sorted),
    ...detectPhraseDisappeared(sorted),
    ...detectDirectNaming(sorted),
    ...detectRecoveryAfterLoop(sorted),
  ];
}

function dedupeMilestones(milestones: EmotionalMilestone[]): EmotionalMilestone[] {
  const seen = new Set<string>();
  return milestones
    .filter((m) => m.strength >= STRONG_MIN)
    .sort((a, b) => b.strength - a.strength)
    .filter((m) => {
      const key = `${m.kind}:${m.entryId ?? m.id}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickBest(milestones: EmotionalMilestone[], limit: number): EmotionalMilestone[] {
  const sorted = dedupeMilestones(milestones);
  const picked: EmotionalMilestone[] = [];
  const usedKinds = new Set<EmotionalMilestoneKind>();

  for (const kind of KIND_PRIORITY) {
    if (picked.length >= limit) break;
    const match = sorted.find((m) => m.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  for (const milestone of sorted) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === milestone.id)) continue;
    picked.push(milestone);
  }

  return picked.slice(0, limit);
}

function applyMilestoneRarity(
  milestones: EmotionalMilestone[],
  context: EmotionalMilestoneContext,
  limit: number,
  record: boolean,
): EmotionalMilestone[] {
  const state = readState();
  const now = Date.now();
  const picked: EmotionalMilestone[] = [];

  for (const milestone of pickBest(milestones, limit * 3)) {
    if (picked.length >= limit) break;

    const key = textKey(milestone.text);
    const recentSameText = state.records.some(
      (r) =>
        r.textKey === key &&
        now - r.shownAt < TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
    );
    if (recentSameText) continue;

    const recentSurface = state.records.some(
      (r) =>
        r.surface === context &&
        now - r.shownAt < SURFACE_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
    );
    if (recentSurface && picked.length > 0) continue;

    const recentSameMilestone = state.records.some(
      (r) =>
        r.milestoneId === milestone.id &&
        now - r.shownAt < TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
    );
    if (recentSameMilestone) continue;

    picked.push(milestone);
  }

  if (record && picked.length > 0) {
    const nextRecords = [
      ...state.records,
      ...picked.map((milestone) => ({
        milestoneId: milestone.id,
        textKey: textKey(milestone.text),
        surface: context,
        shownAt: now,
      })),
    ].slice(-40);
    writeState({ records: nextRecords });
  }

  return picked.slice(0, limit);
}

function filterForEntry(
  milestones: EmotionalMilestone[],
  entryId: string,
): EmotionalMilestone[] {
  return milestones.filter(
    (m) => m.entryId === entryId || m.pastEntryId === entryId,
  );
}

/** Detect rare emotional turning points across the archive. */
export function buildEmotionalMilestonesReport(
  entries: JournalEntry[],
  options: EmotionalMilestoneOptions,
): EmotionalMilestoneReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { milestones: [], hasData: false };
  }

  let candidates = detectAllMilestones(sorted);

  if (options.context === "entry" && options.entryId) {
    candidates = filterForEntry(candidates, options.entryId);
  }

  const milestones = applyMilestoneRarity(
    candidates,
    options.context,
    options.limit ?? 1,
    options.record !== false,
  );

  return { milestones, hasData: milestones.length > 0 };
}

export function memoryMilestoneNotes(
  entries: JournalEntry[],
  limit = 1,
): EmotionalMilestone[] {
  return applyMilestoneHierarchy(
    buildEmotionalMilestonesReport(entries, { context: "memory", limit }).milestones,
    entries,
    limit,
  );
}

export function timelineMilestoneNotes(
  entries: JournalEntry[],
  limit = 1,
): EmotionalMilestone[] {
  return applyMilestoneHierarchy(
    buildEmotionalMilestonesReport(entries, { context: "timeline", limit }).milestones,
    entries,
    limit,
  );
}

export function monthlyMilestoneNotes(
  entries: JournalEntry[],
  limit = 1,
): EmotionalMilestone[] {
  return applyMilestoneHierarchy(
    buildEmotionalMilestonesReport(entries, { context: "monthly", limit }).milestones,
    entries,
    limit,
  );
}

export function entryMilestoneNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): EmotionalMilestone[] {
  return applyMilestoneHierarchy(
    buildEmotionalMilestonesReport(entries, {
      context: "entry",
      entryId,
      limit,
    }).milestones,
    entries,
    limit,
  );
}

export interface MilestoneDepthSignals {
  milestoneCount: number;
  oldEntryMilestoneCount: number;
  spanDays: number;
}

/** Measure milestone accumulation for archive-depth — internal scoring only. */
export function measureMilestoneDepthSignals(entries: JournalEntry[]): MilestoneDepthSignals {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { milestoneCount: 0, oldEntryMilestoneCount: 0, spanDays: 0 };
  }

  const milestones = dedupeMilestones(detectAllMilestones(sorted));
  const today = toDayKey(new Date().toISOString());
  const oldEntryMilestoneCount = milestones.filter((milestone) => {
    const anchorId = milestone.pastEntryId ?? milestone.entryId;
    const anchor = sorted.find((entry) => entry.id === anchorId);
    if (!anchor) return false;
    return daysBetweenKeys(toDayKey(anchor.createdAt), today) >= 21;
  }).length;

  const spanDays = daysBetweenKeys(
    toDayKey(sorted[0].createdAt),
    toDayKey(sorted[sorted.length - 1].createdAt),
  );

  return {
    milestoneCount: milestones.length,
    oldEntryMilestoneCount,
    spanDays,
  };
}

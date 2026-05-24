import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import {
  directCount,
  entrySnippet,
  hedgeCount,
} from "@/lib/memory/language-fingerprint";
import { detectRecoveryCandidates } from "@/lib/memory/recovery-memory";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type EmotionalChapterKind =
  | "before_quieter"
  | "heavier_period"
  | "after_change"
  | "before_direct_naming"
  | "before_phrase_gone"
  | "after_recovery"
  | "theme_dominated"
  | "reads_differently";

export type EmotionalChapterSurface = "entry" | "timeline" | "monthly" | "memory";

export const EMOTIONAL_CHAPTER_COPY = {
  beforeQuieter: "This was before things got quieter.",
  heavierPeriod: "This belonged to a heavier period.",
  afterChange: "A lot changed after this.",
  beforeDirectNaming: "This was before you named it directly.",
} as const;

export const CHAPTER_ENTRY_MIN = 68;
export const CHAPTER_SURFACE_MIN = 78;
export const MIN_ENTRIES = 6;
export const MIN_GAP_DAYS = 14;
export const MIN_ARCHIVE_SPAN_DAYS = 21;
export const SHOW_COOLDOWN_DAYS = 24;
export const TEXT_COOLDOWN_DAYS = 30;
export const MIN_SESSIONS_BETWEEN = 5;

const STATE_KEY = "voicememory_emotional_chapters";

const KIND_COPY: Record<EmotionalChapterKind, string> = {
  before_quieter: EMOTIONAL_CHAPTER_COPY.beforeQuieter,
  heavier_period: EMOTIONAL_CHAPTER_COPY.heavierPeriod,
  after_change: EMOTIONAL_CHAPTER_COPY.afterChange,
  before_direct_naming: EMOTIONAL_CHAPTER_COPY.beforeDirectNaming,
  before_phrase_gone: EMOTIONAL_CHAPTER_COPY.beforeQuieter,
  after_recovery: EMOTIONAL_CHAPTER_COPY.afterChange,
  theme_dominated: EMOTIONAL_CHAPTER_COPY.heavierPeriod,
  reads_differently: EMOTIONAL_CHAPTER_COPY.afterChange,
};

interface ChapterCandidate {
  id: string;
  kind: EmotionalChapterKind;
  text: string;
  strength: number;
  anchorEntryId: string;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId?: string;
}

interface ChapterState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: EmotionalChapterSurface;
    shownAt: number;
  }>;
}

export interface EmotionalChapterReport {
  candidates: ChapterCandidate[];
  hasData: boolean;
}

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

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function evidencePair(past: JournalEntry, current: JournalEntry) {
  return {
    pastQuote: entrySnippet(past),
    currentQuote: entrySnippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

function hasEvidence(
  item: Pick<
    ChapterCandidate,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function readState(): ChapterState {
  const empty: ChapterState = {
    sessionCount: 0,
    lastSessionDay: "",
    sessionsAtLastShow: 0,
    lastShownAt: 0,
    records: [],
  };
  if (!isBrowser()) return empty;
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return empty;
    return JSON.parse(raw) as ChapterState;
  } catch {
    return empty;
  }
}

function writeState(state: ChapterState): void {
  if (!isBrowser()) return;
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

function touchSession(): void {
  const state = readState();
  const today = todayKey();
  if (state.lastSessionDay !== today) {
    state.sessionCount += 1;
    state.lastSessionDay = today;
  }
  writeState(state);
}

function daysSince(at: number): number {
  if (!at) return Number.POSITIVE_INFINITY;
  return (Date.now() - at) / (1000 * 60 * 60 * 24);
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  const cutoff = Date.now() - TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
  return readState().records.some((row) => row.textKey === key && row.shownAt >= cutoff);
}

function shouldAllowSurfaceShow(): boolean {
  const state = readState();
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS_BETWEEN) return false;
  if (daysSince(state.lastShownAt) < SHOW_COOLDOWN_DAYS) return false;
  return true;
}

function recordShown(candidate: ChapterCandidate, surface: EmotionalChapterSurface): void {
  const state = readState();
  const now = Date.now();
  if (surface !== "entry") {
    state.lastShownAt = now;
    state.sessionsAtLastShow = state.sessionCount;
  }
  state.records = [
    ...state.records,
    {
      noteId: candidate.id,
      textKey: textKey(candidate.text),
      surface,
      shownAt: now,
    },
  ].slice(-12);
  writeState(state);
}

function pushCandidate(
  bucket: ChapterCandidate[],
  item: Omit<ChapterCandidate, "strength"> & { strength?: number },
  minStrength: number,
): void {
  const strength = item.strength ?? 55;
  if (strength < minStrength) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function entryGaps(entries: JournalEntry[]): number[] {
  const gaps: number[] = [];
  for (let i = 1; i < entries.length; i += 1) {
    gaps.push(
      daysBetweenKeys(toDayKey(entries[i - 1].createdAt), toDayKey(entries[i].createdAt)),
    );
  }
  return gaps;
}

function detectBeforeQuieter(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const later = sorted.slice(anchorIdx + 1);
  if (later.length < 3) return null;

  const beforeWindow = sorted.slice(Math.max(0, anchorIdx - 3), anchorIdx + 1);
  const afterWindow = later.slice(0, Math.min(4, later.length));
  const beforeAvg = roundAvg(beforeWindow.map((e) => e.reflection.emotionalIntensity));
  const afterAvg = roundAvg(afterWindow.map((e) => e.reflection.emotionalIntensity));
  const intensityDrop = beforeAvg - afterAvg;

  const beforeGaps = entryGaps(beforeWindow);
  const afterGaps = entryGaps(afterWindow);
  const gapWidened =
    afterGaps.length >= 2 &&
    beforeGaps.length >= 1 &&
    median(afterGaps) >= median(beforeGaps) * 1.35 + 3;

  if (intensityDrop < 1.2 && !gapWidened) return null;

  const pivot = afterWindow[0];
  const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(pivot.createdAt));
  if (gap < MIN_GAP_DAYS) return null;

  return {
    id: `chapter-quieter-${anchor.id}`,
    kind: "before_quieter",
    text: KIND_COPY.before_quieter,
    anchorEntryId: anchor.id,
    strength: 72 + Math.round(intensityDrop * 3) + (gapWidened ? 4 : 0) + Math.min(gap, 8),
    ...evidencePair(anchor, pivot),
  };
}

function detectHeavierPeriod(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const windowStart = Math.max(0, anchorIdx - 2);
  const window = sorted.slice(windowStart, windowStart + 4);
  if (window.length < 3) return null;
  if (!window.some((e) => e.id === anchor.id)) return null;

  const heavyCount = window.filter((e) => e.reflection.emotionalIntensity >= 6).length;
  const avgIntensity = roundAvg(window.map((e) => e.reflection.emotionalIntensity));
  if (heavyCount < 2 && avgIntensity < 5.8) return null;

  const later = sorted[anchorIdx + 1];
  if (!later) return null;

  return {
    id: `chapter-heavier-${anchor.id}`,
    kind: "heavier_period",
    text: KIND_COPY.heavier_period,
    anchorEntryId: anchor.id,
    strength: 74 + heavyCount * 3 + Math.round(avgIntensity),
    pastQuote: entrySnippet(anchor),
    currentQuote: entrySnippet(later),
    pastDateLabel: formatRelativeDate(anchor.createdAt),
    currentDateLabel: formatRelativeDate(later.createdAt),
    pastEntryId: anchor.id,
    entryId: later.id,
  };
}

function detectBeforeDirectNaming(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  if (directCount(anchor) >= 1) return null;

  const later = sorted.slice(anchorIdx + 1);
  for (const compare of later) {
    const overlap = sharedThemes(anchor, compare);
    if (overlap.length === 0) continue;
    if (directCount(compare) < 1) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(compare.createdAt));
    if (gap < MIN_GAP_DAYS) continue;

    return {
      id: `chapter-before-name-${anchor.id}-${compare.id}`,
      kind: "before_direct_naming",
      text: KIND_COPY.before_direct_naming,
      anchorEntryId: anchor.id,
      strength: 76 + directCount(compare) * 2 + Math.min(gap, 10),
      ...evidencePair(anchor, compare),
    };
  }

  return null;
}

function detectAfterChange(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const later = sorted.slice(anchorIdx + 1, anchorIdx + 5);
  if (later.length < 2) return null;

  const beforeAvg = anchor.reflection.emotionalIntensity;
  const afterAvg = roundAvg(later.map((e) => e.reflection.emotionalIntensity));
  const directGain =
    roundAvg(later.map((e) => directCount(e))) - directCount(anchor);
  const hedgeDrop = hedgeCount(anchor) - roundAvg(later.map((e) => hedgeCount(e)));

  const shifted =
    Math.abs(afterAvg - beforeAvg) >= 1.5 ||
    directGain >= 1.5 ||
    hedgeDrop >= 1.5;
  if (!shifted) return null;

  const overlap = later.some((e) => sharedThemes(anchor, e).length > 0);
  if (!overlap) return null;

  const compare = later[later.length - 1];
  const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(compare.createdAt));
  if (gap < MIN_GAP_DAYS) return null;

  return {
    id: `chapter-after-${anchor.id}-${compare.id}`,
    kind: "after_change",
    text: KIND_COPY.after_change,
    anchorEntryId: anchor.id,
    strength: 75 + Math.round(Math.abs(afterAvg - beforeAvg) * 2) + Math.min(gap, 8),
    ...evidencePair(anchor, compare),
  };
}

function detectBeforePhraseGone(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const phrases = buildPhraseMemory(sorted);
  const anchorDay = toDayKey(anchor.createdAt);

  for (const record of phrases) {
    if (record.count < 3) continue;
    if (!record.entryIds.includes(anchor.id)) continue;

    const lastIdx = record.entryIds.indexOf(anchor.id);
    const laterIds = record.entryIds.slice(lastIdx + 1);
    if (laterIds.length > 0) continue;

    const laterEntries = sorted.slice(anchorIdx + 1);
    if (laterEntries.length < 3) continue;

    const spanAfter = daysBetweenKeys(
      anchorDay,
      toDayKey(laterEntries[Math.min(2, laterEntries.length - 1)].createdAt),
    );
    if (spanAfter < MIN_GAP_DAYS) continue;

    const compare = laterEntries[0];
    return {
      id: `chapter-phrase-${record.phrase.replace(/\s+/g, "-").slice(0, 12)}-${anchor.id}`,
      kind: "before_phrase_gone",
      text: KIND_COPY.before_phrase_gone,
      anchorEntryId: anchor.id,
      strength: 73 + record.count * 2 + Math.min(spanAfter, 12),
      ...evidencePair(anchor, compare),
    };
  }

  return null;
}

function detectAfterRecovery(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const prior = sorted.slice(0, anchorIdx);
  const recoveries = detectRecoveryCandidates(anchor, prior);
  const best = recoveries.sort((a, b) => b.strength - a.strength)[0];
  if (!best || best.strength < 64) return null;

  const past = prior.find((e) => e.id === best.pastEntryId);
  if (!past) return null;

  return {
    id: `chapter-recovery-${anchor.id}`,
    kind: "after_recovery",
    text: KIND_COPY.after_recovery,
    anchorEntryId: anchor.id,
    strength: best.strength + 4,
    pastQuote: best.pastQuote,
    currentQuote: best.currentQuote,
    pastDateLabel: best.pastDateLabel,
    currentDateLabel: best.currentDateLabel,
    pastEntryId: best.pastEntryId,
    entryId: best.entryId,
  };
}

function detectThemeDominated(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const windowStart = Math.max(0, anchorIdx - 2);
  const window = sorted.slice(windowStart, windowStart + 5);
  if (window.length < 4) return null;
  if (!window.some((e) => e.id === anchor.id)) return null;

  const themeCounts = new Map<string, number>();
  for (const entry of window) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      themeCounts.set(key, (themeCounts.get(key) ?? 0) + 1);
    }
  }

  let dominant: string | null = null;
  let dominantCount = 0;
  for (const [theme, count] of themeCounts) {
    if (count > dominantCount) {
      dominant = theme;
      dominantCount = count;
    }
  }

  if (!dominant || dominantCount < 3) return null;
  if (!hasTheme(anchor, dominant)) return null;

  const later = sorted[anchorIdx + 1];
  if (!later) return null;

  return {
    id: `chapter-theme-${dominant.slice(0, 10)}-${anchor.id}`,
    kind: "theme_dominated",
    text: KIND_COPY.theme_dominated,
    anchorEntryId: anchor.id,
    strength: 74 + dominantCount * 3,
    pastQuote: entrySnippet(anchor),
    currentQuote: entrySnippet(later),
    pastDateLabel: formatRelativeDate(anchor.createdAt),
    currentDateLabel: formatRelativeDate(later.createdAt),
    pastEntryId: anchor.id,
    entryId: later.id,
  };
}

function detectReadsDifferently(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  anchorIdx: number,
): ChapterCandidate | null {
  const latest = sorted[sorted.length - 1];
  const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(latest.createdAt));
  if (gap < MIN_ARCHIVE_SPAN_DAYS) return null;
  if (sorted.length - anchorIdx < 4) return null;

  const overlap = sharedThemes(anchor, latest);
  if (overlap.length === 0) return null;

  const intensityShift = Math.abs(
    anchor.reflection.emotionalIntensity - latest.reflection.emotionalIntensity,
  );
  const hedgeShift = Math.abs(hedgeCount(anchor) - hedgeCount(latest));
  const directShift = Math.abs(directCount(anchor) - directCount(latest));
  if (intensityShift < 1.5 && hedgeShift < 2 && directShift < 1) return null;

  return {
    id: `chapter-reads-${anchor.id}-${latest.id}`,
    kind: "reads_differently",
    text: KIND_COPY.reads_differently,
    anchorEntryId: anchor.id,
    strength: 77 + Math.round(intensityShift * 2) + hedgeShift + Math.min(gap, 10),
    ...evidencePair(anchor, latest),
  };
}

function collectForAnchor(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  minStrength: number,
): ChapterCandidate[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const anchorIdx = sorted.findIndex((row) => row.id === anchor.id);
  if (anchorIdx < 0) return [];

  const notes: ChapterCandidate[] = [];
  const detectors = [
    () => detectBeforeQuieter(sorted, anchor, anchorIdx),
    () => detectHeavierPeriod(sorted, anchor, anchorIdx),
    () => detectBeforeDirectNaming(sorted, anchor, anchorIdx),
    () => detectAfterChange(sorted, anchor, anchorIdx),
    () => detectBeforePhraseGone(sorted, anchor, anchorIdx),
    () => detectAfterRecovery(sorted, anchor, anchorIdx),
    () => detectThemeDominated(sorted, anchor, anchorIdx),
    () => detectReadsDifferently(sorted, anchor, anchorIdx),
  ];

  for (const detector of detectors) {
    const candidate = detector();
    if (candidate) pushCandidate(notes, candidate, minStrength);
  }

  return notes;
}

function toMemoryNote(candidate: ChapterCandidate): MemoryNote {
  return {
    id: candidate.id,
    text: candidate.text,
    category: "changed",
    confidence: candidate.strength,
    pastQuote: candidate.pastQuote,
    currentQuote: candidate.currentQuote,
    pastDateLabel: candidate.pastDateLabel,
    currentDateLabel: candidate.currentDateLabel,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId,
  };
}

/** Internal ranking — emotional chapter candidates for an anchor entry. */
export function buildEmotionalChapterReport(
  entries: JournalEntry[],
  anchorEntryId?: string,
  minStrength = CHAPTER_ENTRY_MIN,
): EmotionalChapterReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const span =
    sorted.length >= 2
      ? daysBetweenKeys(
          toDayKey(sorted[0].createdAt),
          toDayKey(sorted[sorted.length - 1].createdAt),
        )
      : 0;
  if (span < MIN_ARCHIVE_SPAN_DAYS) {
    return { candidates: [], hasData: false };
  }

  const anchors = anchorEntryId
    ? sorted.filter((row) => row.id === anchorEntryId)
    : sorted.slice(0, -2);

  const candidates = anchors
    .flatMap((anchor) => collectForAnchor(sorted, anchor, minStrength))
    .sort((a, b) => b.strength - a.strength)
    .filter((note, index, list) => {
      const key = `${note.anchorEntryId}:${note.kind}`;
      return list.findIndex((row) => `${row.anchorEntryId}:${row.kind}` === key) === index;
    });

  return { candidates, hasData: candidates.length > 0 };
}

function pickBest(
  entries: JournalEntry[],
  anchorEntryId: string | undefined,
  surface: EmotionalChapterSurface,
  minStrength: number,
): MemoryNote | null {
  touchSession();
  if (surface !== "entry" && !shouldAllowSurfaceShow()) return null;

  const report = buildEmotionalChapterReport(entries, anchorEntryId, minStrength);
  const best = report.candidates[0];
  if (!best || best.strength < minStrength) return null;
  if (isTextFatigued(best.text)) return null;

  recordShown(best, surface);
  return toMemoryNote(best);
}

/** Entry revisit — one quiet line about when this reflection belonged. */
export function pickEmotionalChapterForEntry(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote | null {
  const sorted = sortedEntries(entries);
  const idx = sorted.findIndex((row) => row.id === entryId);
  if (idx < 0 || idx >= sorted.length - 1) return null;
  return pickBest(entries, entryId, "entry", CHAPTER_ENTRY_MIN);
}

function pickSurfaceMoment(
  entries: JournalEntry[],
  surface: "timeline" | "monthly" | "memory",
): MemoryNote | null {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) return null;

  const note = pickBest(entries, undefined, surface, CHAPTER_SURFACE_MIN);
  if (!note) return null;

  return calibratePrimaryNote([note], sorted, surface === "memory" ? "memory" : surface);
}

export function timelineEmotionalChapterMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "timeline");
}

export function monthlyEmotionalChapterMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "monthly");
}

export function memoryEmotionalChapterMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "memory");
}

import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { WEDGE_RESURFACING } from "@/lib/product-copy";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { guardSurfacedNote } from "@/lib/refinement/false-positive-suppression";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type LivingResurfacingKind =
  | "new_meaning_after_later"
  | "reads_differently_after_later"
  | "connected_multiple_changes"
  | "repeated_revisit_bookmark"
  | "growing_relevance";

export type LivingResurfacingSurface = "homepage" | "memory" | "entry";

export const LIVING_RESURFACING_COPY = {
  newMeaningAfterLater: WEDGE_RESURFACING.pastWordsMatch,
  multipleReturnWays: WEDGE_RESURFACING.saidBeforeLeftAlone,
  readsDifferentlyAfterLater: WEDGE_RESURFACING.similarWordsBefore,
  usedToSitCenter: WEDGE_RESURFACING.concernAgain,
} as const;

export const LIVING_ENTRY_MIN = 68;
export const LIVING_SURFACE_MIN = 76;
export const MIN_ARCHIVE_ENTRIES = 10;
export const MIN_LATER_GAP_DAYS = 14;
export const MIN_ARCHIVE_SPAN_DAYS = 30;
export const SHOW_COOLDOWN_DAYS = 21;
export const TEXT_COOLDOWN_DAYS = 28;
export const MIN_SESSIONS_BETWEEN = 4;
export const ENTRY_TEXT_COOLDOWN_DAYS = 10;

const STATE_KEY = "voicememory_living_resurfacing";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|directly)\b/gi;
const NAMED_RE = /\b(mum|dad|mother|father|partner|boss|friend|colleague)\b/gi;

const KIND_COPY: Record<LivingResurfacingKind, string> = {
  new_meaning_after_later: LIVING_RESURFACING_COPY.newMeaningAfterLater,
  reads_differently_after_later: LIVING_RESURFACING_COPY.readsDifferentlyAfterLater,
  connected_multiple_changes: LIVING_RESURFACING_COPY.readsDifferentlyAfterLater,
  repeated_revisit_bookmark: LIVING_RESURFACING_COPY.multipleReturnWays,
  growing_relevance: LIVING_RESURFACING_COPY.usedToSitCenter,
};

const SURFACE_KIND_PRIORITY: Record<LivingResurfacingSurface, LivingResurfacingKind[]> = {
  entry: [
    "repeated_revisit_bookmark",
    "reads_differently_after_later",
    "new_meaning_after_later",
    "connected_multiple_changes",
    "growing_relevance",
  ],
  homepage: [
    "new_meaning_after_later",
    "reads_differently_after_later",
    "growing_relevance",
    "connected_multiple_changes",
    "repeated_revisit_bookmark",
  ],
  memory: [
    "growing_relevance",
    "new_meaning_after_later",
    "reads_differently_after_later",
    "connected_multiple_changes",
    "repeated_revisit_bookmark",
  ],
};

interface LivingResurfacingCandidate {
  id: string;
  kind: LivingResurfacingKind;
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

interface LivingState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: LivingResurfacingSurface;
    anchorEntryId?: string;
    shownAt: number;
  }>;
}

export interface LivingResurfacingReport {
  candidates: LivingResurfacingCandidate[];
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

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function entryText(entry: JournalEntry): string {
  return `${entry.transcript} ${entry.reflection.concreteObservation ?? ""}`.trim();
}

function isCalmerOrDirect(before: JournalEntry, after: JournalEntry): boolean {
  const beforeText = entryText(before);
  const afterText = entryText(after);
  const hedgedBefore = countMatches(beforeText, HEDGE_RE) >= 1;
  const directAfter =
    countMatches(afterText, DIRECT_RE) >= 1 || countMatches(afterText, NAMED_RE) >= 1;
  const intensityDrop =
    before.reflection.emotionalIntensity - after.reflection.emotionalIntensity >= 1.5;
  const calmerAfter = after.reflection.emotionalIntensity <= 4.5 && before.reflection.emotionalIntensity >= 5.5;
  return (hedgedBefore && directAfter) || intensityDrop || calmerAfter;
}

function evidencePair(past: JournalEntry, current: JournalEntry) {
  return {
    pastQuote: snippet(past),
    currentQuote: snippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

function hasEvidence(
  item: Pick<
    LivingResurfacingCandidate,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function readState(): LivingState {
  const empty: LivingState = {
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
    return JSON.parse(raw) as LivingState;
  } catch {
    return empty;
  }
}

function writeState(state: LivingState): void {
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

function isTextFatigued(text: string, surface: LivingResurfacingSurface, anchorEntryId?: string): boolean {
  const key = textKey(text);
  const cutoff =
    Date.now() -
    (surface === "entry" ? ENTRY_TEXT_COOLDOWN_DAYS : TEXT_COOLDOWN_DAYS) *
      24 *
      60 *
      60 *
      1000;
  return readState().records.some((row) => {
    if (row.shownAt < cutoff) return false;
    if (row.textKey !== key) return false;
    if (surface === "entry" && anchorEntryId) {
      return row.anchorEntryId === anchorEntryId;
    }
    return row.surface === surface || surface !== "entry";
  });
}

function shouldAllowSurfaceShow(): boolean {
  const state = readState();
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS_BETWEEN) return false;
  if (daysSince(state.lastShownAt) < SHOW_COOLDOWN_DAYS) return false;
  return true;
}

function recordShown(
  candidate: LivingResurfacingCandidate,
  surface: LivingResurfacingSurface,
): void {
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
      anchorEntryId: candidate.anchorEntryId,
      shownAt: now,
    },
  ].slice(-20);
  writeState(state);
}

function pushCandidate(
  bucket: LivingResurfacingCandidate[],
  item: Omit<LivingResurfacingCandidate, "strength"> & { strength?: number },
  minStrength: number,
): void {
  const strength = item.strength ?? 55;
  if (strength < minStrength) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function laterEntriesFor(anchor: JournalEntry, sorted: JournalEntry[]): JournalEntry[] {
  const anchorTime = new Date(anchor.createdAt).getTime();
  return sorted.filter((row) => new Date(row.createdAt).getTime() > anchorTime);
}

function connectedLaterEntries(anchor: JournalEntry, sorted: JournalEntry[]): JournalEntry[] {
  return laterEntriesFor(anchor, sorted).filter((row) => {
    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(row.createdAt));
    if (gap < MIN_LATER_GAP_DAYS) return false;
    return sharedThemes(anchor, row).length > 0;
  });
}

function detectNewMeaningAfterLater(sorted: JournalEntry[]): LivingResurfacingCandidate[] {
  const notes: LivingResurfacingCandidate[] = [];
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return notes;

  for (const anchor of sorted.slice(0, -3)) {
    const connected = connectedLaterEntries(anchor, sorted);
    if (connected.length < 2) continue;

    const shifted = connected.filter((row) => isCalmerOrDirect(anchor, row));
    if (shifted.length === 0) continue;

    const latest = connected[connected.length - 1];
    pushCandidate(
      notes,
      {
        id: `living-new-meaning-${anchor.id}`,
        kind: "new_meaning_after_later",
        text: KIND_COPY.new_meaning_after_later,
        anchorEntryId: anchor.id,
        strength: 70 + connected.length * 2 + shifted.length * 3,
        ...evidencePair(anchor, latest),
      },
      LIVING_ENTRY_MIN,
    );
  }

  return notes;
}

function detectReadsDifferentlyAfterLater(sorted: JournalEntry[]): LivingResurfacingCandidate[] {
  const notes: LivingResurfacingCandidate[] = [];

  for (const anchor of sorted.slice(0, -2)) {
    const connected = connectedLaterEntries(anchor, sorted);
    const contrasting = connected.filter((row) => isCalmerOrDirect(anchor, row));
    if (contrasting.length === 0) continue;

    const best = contrasting[contrasting.length - 1];
    pushCandidate(
      notes,
      {
        id: `living-reads-different-${anchor.id}`,
        kind: "reads_differently_after_later",
        text: KIND_COPY.reads_differently_after_later,
        anchorEntryId: anchor.id,
        strength: 72 + contrasting.length * 3,
        ...evidencePair(anchor, best),
      },
      LIVING_ENTRY_MIN,
    );
  }

  return notes;
}

function detectConnectedMultipleChanges(sorted: JournalEntry[]): LivingResurfacingCandidate[] {
  const notes: LivingResurfacingCandidate[] = [];

  for (const anchor of sorted.slice(0, -4)) {
    const connected = connectedLaterEntries(anchor, sorted);
    if (connected.length < 3) continue;

    const months = new Set(connected.map((row) => toDayKey(row.createdAt).slice(0, 7)));
    if (months.size < 2) continue;

    const latest = connected[connected.length - 1];
    pushCandidate(
      notes,
      {
        id: `living-multi-change-${anchor.id}`,
        kind: "connected_multiple_changes",
        text: KIND_COPY.connected_multiple_changes,
        anchorEntryId: anchor.id,
        strength: 74 + connected.length * 2 + months.size * 2,
        ...evidencePair(anchor, latest),
      },
      LIVING_ENTRY_MIN,
    );
  }

  return notes;
}

function detectRepeatedRevisitBookmark(sorted: JournalEntry[]): LivingResurfacingCandidate[] {
  const notes: LivingResurfacingCandidate[] = [];
  if (!isBrowser()) return notes;

  for (const anchor of sorted.slice(0, -2)) {
    const later = laterEntriesFor(anchor, sorted);
    if (later.length < 2) continue;

    const summary = entryInteractionSummary(anchor.id);
    const bookmark = getBookmarkForEntry(anchor.id);
    const views = summary?.viewCount ?? 0;
    const marked = Boolean(bookmark) || views >= 2;
    if (!marked) continue;

    const gap = daysBetweenKeys(
      toDayKey(anchor.createdAt),
      toDayKey(later[later.length - 1].createdAt),
    );
    if (gap < MIN_LATER_GAP_DAYS) continue;

    pushCandidate(
      notes,
      {
        id: `living-return-ways-${anchor.id}`,
        kind: "repeated_revisit_bookmark",
        text: KIND_COPY.repeated_revisit_bookmark,
        anchorEntryId: anchor.id,
        strength: 73 + views * 2 + (bookmark ? 5 : 0) + Math.min(later.length, 4),
        ...evidencePair(anchor, later[later.length - 1]),
      },
      LIVING_ENTRY_MIN,
    );
  }

  return notes;
}

function detectGrowingRelevance(sorted: JournalEntry[]): LivingResurfacingCandidate[] {
  const notes: LivingResurfacingCandidate[] = [];
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return notes;

  const span = daysBetweenKeys(
    toDayKey(sorted[0].createdAt),
    toDayKey(sorted[sorted.length - 1].createdAt),
  );
  if (span < MIN_ARCHIVE_SPAN_DAYS) return notes;

  const midpoint = Math.floor(sorted.length / 2);
  const early = sorted.slice(0, midpoint);

  for (const anchor of early) {
    if (anchor.reflection.emotionalIntensity < 5.5) continue;

    const earlyLinks = early.filter(
      (row) => row.id !== anchor.id && sharedThemes(anchor, row).length > 0,
    ).length;
    if (earlyLinks < 1) continue;

    const connected = connectedLaterEntries(anchor, sorted);
    if (connected.length < 2) continue;

    const recent = connected.filter((row) => {
      const gap = daysBetweenKeys(toDayKey(row.createdAt), toDayKey(sorted[sorted.length - 1].createdAt));
      return gap <= 45;
    });
    if (recent.length === 0) continue;

    pushCandidate(
      notes,
      {
        id: `living-center-${anchor.id}`,
        kind: "growing_relevance",
        text: KIND_COPY.growing_relevance,
        anchorEntryId: anchor.id,
        strength: 71 + connected.length * 2 + recent.length * 3 + earlyLinks * 2,
        ...evidencePair(anchor, recent[recent.length - 1]),
      },
      LIVING_ENTRY_MIN,
    );
  }

  return notes;
}

function collectCandidates(
  sorted: JournalEntry[],
  surface: LivingResurfacingSurface,
  anchorEntryId?: string,
): LivingResurfacingCandidate[] {
  const notes = [
    ...detectNewMeaningAfterLater(sorted),
    ...detectReadsDifferentlyAfterLater(sorted),
    ...detectConnectedMultipleChanges(sorted),
    ...detectRepeatedRevisitBookmark(sorted),
    ...detectGrowingRelevance(sorted),
  ];

  const priority = SURFACE_KIND_PRIORITY[surface];
  const seen = new Set<string>();

  return notes
    .filter((note) => !anchorEntryId || note.anchorEntryId === anchorEntryId)
    .filter((note) => !isTextFatigued(note.text, surface, note.anchorEntryId))
    .sort((a, b) => {
      const aPri = priority.indexOf(a.kind);
      const bPri = priority.indexOf(b.kind);
      if (aPri !== bPri) return aPri - bPri;
      return b.strength - a.strength;
    })
    .filter((note) => {
      const key = `${note.anchorEntryId}:${textKey(note.text)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function toMemoryNote(candidate: LivingResurfacingCandidate): MemoryNote {
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

/** Internal ranking — all living resurfacing candidates. */
export function buildLivingResurfacingReport(
  entries: JournalEntry[],
  surface: LivingResurfacingSurface,
  anchorEntryId?: string,
): LivingResurfacingReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const candidates = collectCandidates(sorted, surface, anchorEntryId);
  return { candidates, hasData: candidates.length > 0 };
}

/** Entry revisit — one quiet line when an old reflection has shifted meaning. */
export function pickLivingResurfacingForEntry(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote | null {
  touchSession();
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return null;

  const anchorIndex = sorted.findIndex((row) => row.id === entryId);
  if (anchorIndex < 0 || anchorIndex >= sorted.length - 2) return null;

  const report = buildLivingResurfacingReport(entries, "entry", entryId);
  const best = report.candidates[0];
  if (!best || best.strength < LIVING_ENTRY_MIN) return null;

  recordShown(best, "entry");
  return guardSurfacedNote(toMemoryNote(best), sorted, "living_resurfacing");
}

function pickSurfaceMoment(
  entries: JournalEntry[],
  surface: "homepage" | "memory",
): MemoryNote | null {
  touchSession();
  if (!shouldAllowSurfaceShow()) return null;

  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return null;

  const report = buildLivingResurfacingReport(entries, surface);
  const best = report.candidates[0];
  if (!best || best.strength < LIVING_SURFACE_MIN) return null;

  const calibrated = calibratePrimaryNote([toMemoryNote(best)], sorted, surface);
  if (!calibrated) return null;

  recordShown(best, surface);
  return guardSurfacedNote(calibrated, sorted, "living_resurfacing");
}

export function homepageLivingResurfacingMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "homepage");
}

export function memoryLivingResurfacingMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "memory");
}

import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { guardSurfacedNote } from "@/lib/refinement/false-positive-suppression";
import { formatRelativeDate } from "@/lib/utils";
import type { EmotionalMilestone } from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type DelayedPayoffThreshold = 14 | 30 | 60;

export type DelayedPayoffKind =
  | "distance_tiered"
  | "phrase_absent"
  | "concern_absent"
  | "contrast_widened"
  | "reads_differently_later"
  | "revisited_related";

export const DELAYED_PAYOFF_COPY = {
  readsClearlyWithDistance: "This only reads clearly with distance.",
  hadToGetFurtherAway: "You had to get further away from this.",
  tookTimeToBecomeVisible: "This took time to become visible.",
  feelsDifferentWithTime: "This feels different now because time passed.",
} as const;

export const DELAYED_PAYOFF_MIN = 72;
export const MIN_ARCHIVE_ENTRIES = 8;
export const SHOW_COOLDOWN_DAYS = 28;
export const TEXT_COOLDOWN_DAYS = 35;
export const MIN_SESSIONS_BETWEEN = 5;

const STATE_KEY = "voicememory_delayed_payoff";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague|worried|anxious|stress)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|directly)\b/gi;

const KIND_COPY: Record<DelayedPayoffKind, string> = {
  distance_tiered: DELAYED_PAYOFF_COPY.tookTimeToBecomeVisible,
  phrase_absent: DELAYED_PAYOFF_COPY.feelsDifferentWithTime,
  concern_absent: DELAYED_PAYOFF_COPY.hadToGetFurtherAway,
  contrast_widened: DELAYED_PAYOFF_COPY.readsClearlyWithDistance,
  reads_differently_later: DELAYED_PAYOFF_COPY.feelsDifferentWithTime,
  revisited_related: DELAYED_PAYOFF_COPY.readsClearlyWithDistance,
};

interface DelayedPayoffClassification {
  kind: DelayedPayoffKind;
  threshold: DelayedPayoffThreshold;
  gapDays: number;
  anchorEntryId?: string;
}

interface DelayedPayoffCandidate {
  id: string;
  kind: DelayedPayoffKind;
  text: string;
  strength: number;
  threshold: DelayedPayoffThreshold;
  gapDays: number;
  anchorEntryId: string;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId?: string;
}

interface DelayedState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    kind: DelayedPayoffKind;
    shownAt: number;
  }>;
}

export interface DelayedPayoffReport {
  candidates: DelayedPayoffCandidate[];
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
    DelayedPayoffCandidate,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function readState(): DelayedState {
  const empty: DelayedState = {
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
    return JSON.parse(raw) as DelayedState;
  } catch {
    return empty;
  }
}

function writeState(state: DelayedState): void {
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

function isCopyFatigued(text: string): boolean {
  const key = textKey(text);
  const cutoff = Date.now() - TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
  return readState().records.some((row) => row.textKey === key && row.shownAt >= cutoff);
}

function shouldApplyDelayedCopy(): boolean {
  touchSession();
  const state = readState();
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS_BETWEEN) return false;
  if (daysSince(state.lastShownAt) < SHOW_COOLDOWN_DAYS) return false;
  return true;
}

function recordDelayedCopy(kind: DelayedPayoffKind, text: string, noteId: string): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    { noteId, textKey: textKey(text), kind, shownAt: now },
  ].slice(-12);
  writeState(state);
}

function hasRevisitedRelated(entries: JournalEntry[], entryId: string): boolean {
  if (!isBrowser()) return false;
  const summary = entryInteractionSummary(entryId);
  const bookmark = getBookmarkForEntry(entryId);
  return Boolean(bookmark) || (summary?.viewCount ?? 0) >= 2;
}

/** Days between the note's past anchor and its current anchor (or today). */
export function gapDaysForNote(entries: JournalEntry[], note: MemoryNote): number {
  const sorted = sortedEntries(entries);
  const past = note.pastEntryId
    ? sorted.find((row) => row.id === note.pastEntryId)
    : undefined;
  const current = note.entryId
    ? sorted.find((row) => row.id === note.entryId)
    : sorted[sorted.length - 1];

  if (past && current) {
    return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
  }
  if (past) {
    return daysBetweenKeys(toDayKey(past.createdAt), todayKey());
  }
  return 0;
}

function thresholdForGap(gapDays: number): DelayedPayoffThreshold {
  if (gapDays >= 60) return 60;
  if (gapDays >= 30) return 30;
  return 14;
}

export function classifyDelayedPayoff(
  entries: JournalEntry[],
  note: MemoryNote,
): DelayedPayoffClassification | null {
  const gapDays = gapDaysForNote(entries, note);
  const id = note.id;

  if (
    id.includes("phrase-gone") ||
    id.includes("resurface-phrase") ||
    id.startsWith("change-phrase-gone")
  ) {
    return { kind: "phrase_absent", threshold: 30, gapDays, anchorEntryId: note.pastEntryId };
  }

  if (
    id.includes("topic_absent") ||
    id.startsWith("resurface-topic-") ||
    id.startsWith("change-absent") ||
    id.startsWith("revisit-topic-")
  ) {
    return { kind: "concern_absent", threshold: 30, gapDays, anchorEntryId: note.pastEntryId };
  }

  if (
    id.startsWith("knows-me-contrast") ||
    id.startsWith("tvn-") ||
    id.startsWith("revisit-diff") ||
    id.startsWith("change-charged") ||
    id.startsWith("change-emotional")
  ) {
    return {
      kind: "contrast_widened",
      threshold: thresholdForGap(gapDays),
      gapDays,
      anchorEntryId: note.pastEntryId,
    };
  }

  if (
    id.startsWith("living-") ||
    id.startsWith("knows-me-wording") ||
    id.startsWith("knows-me-earlier") ||
    id.startsWith("archive-gravity") ||
    id.startsWith("change-direct") ||
    id.startsWith("change-hedge")
  ) {
    return {
      kind: "reads_differently_later",
      threshold: gapDays >= 60 ? 60 : 30,
      gapDays,
      anchorEntryId: note.pastEntryId ?? note.entryId,
    };
  }

  if (note.pastEntryId && hasRevisitedRelated(entries, note.pastEntryId)) {
    return {
      kind: "revisited_related",
      threshold: 14,
      gapDays,
      anchorEntryId: note.pastEntryId,
    };
  }

  if (note.pastEntryId && gapDays >= 14) {
    return {
      kind: "distance_tiered",
      threshold: thresholdForGap(gapDays),
      gapDays,
      anchorEntryId: note.pastEntryId,
    };
  }

  return null;
}

export function classifyDelayedPayoffMilestone(
  entries: JournalEntry[],
  milestone: EmotionalMilestone,
): DelayedPayoffClassification | null {
  const gapDays =
    milestone.pastEntryId && milestone.entryId
      ? gapDaysForNote(entries, {
          id: milestone.id,
          text: milestone.text,
          category: "changed",
          confidence: milestone.strength,
          pastEntryId: milestone.pastEntryId,
          entryId: milestone.entryId,
        })
      : 0;

  if (milestone.kind === "phrase_disappeared") {
    return { kind: "phrase_absent", threshold: 30, gapDays, anchorEntryId: milestone.pastEntryId };
  }
  if (milestone.kind === "topic_absent_after_intensity") {
    return { kind: "concern_absent", threshold: 30, gapDays, anchorEntryId: milestone.pastEntryId };
  }
  if (milestone.kind === "first_calmer_topic" || milestone.kind === "recovery_after_loop") {
    return {
      kind: "contrast_widened",
      threshold: gapDays >= 30 ? 30 : 14,
      gapDays,
      anchorEntryId: milestone.pastEntryId ?? milestone.entryId,
    };
  }
  if (milestone.kind === "direct_naming") {
    return {
      kind: "reads_differently_later",
      threshold: 30,
      gapDays,
      anchorEntryId: milestone.pastEntryId ?? milestone.entryId,
    };
  }
  if (milestone.pastEntryId && gapDays >= 14) {
    return {
      kind: "distance_tiered",
      threshold: thresholdForGap(gapDays),
      gapDays,
      anchorEntryId: milestone.pastEntryId,
    };
  }
  return null;
}

/** Block notes that need more distance before they can surface. */
export function passesDelayedPayoffGate(entries: JournalEntry[], note: MemoryNote): boolean {
  const classification = classifyDelayedPayoff(entries, note);
  if (!classification) {
    if (!note.pastEntryId) return true;
    return gapDaysForNote(entries, note) >= 14;
  }
  return classification.gapDays >= classification.threshold;
}

export function passesDelayedPayoffMilestoneGate(
  entries: JournalEntry[],
  milestone: EmotionalMilestone,
): boolean {
  const classification = classifyDelayedPayoffMilestone(entries, milestone);
  if (!classification) {
    if (!milestone.pastEntryId) return true;
    const gap =
      milestone.pastEntryId && milestone.entryId
        ? gapDaysForNote(entries, {
            id: milestone.id,
            text: milestone.text,
            category: "changed",
            confidence: milestone.strength,
            pastEntryId: milestone.pastEntryId,
            entryId: milestone.entryId,
          })
        : 0;
    return gap >= 14;
  }
  return classification.gapDays >= classification.threshold;
}

export function applyDelayedPayoffFraming(
  entries: JournalEntry[],
  note: MemoryNote,
): MemoryNote {
  const classification = classifyDelayedPayoff(entries, note);
  if (!classification) return note;
  if (classification.gapDays < classification.threshold) return note;
  if (note.confidence < DELAYED_PAYOFF_MIN && classification.kind !== "revisited_related") {
    return note;
  }
  if (!shouldApplyDelayedCopy()) return note;
  if (isCopyFatigued(KIND_COPY[classification.kind])) return note;

  const text = KIND_COPY[classification.kind];
  if (!helpsOrient(text, note.confidence)) return note;

  recordDelayedCopy(classification.kind, text, note.id);
  return { ...note, text };
}

function applyDelayedPayoffMilestoneFraming(
  entries: JournalEntry[],
  milestone: EmotionalMilestone,
): EmotionalMilestone {
  const classification = classifyDelayedPayoffMilestone(entries, milestone);
  if (!classification) return milestone;
  if (classification.gapDays < classification.threshold) return milestone;
  if (milestone.strength < DELAYED_PAYOFF_MIN) return milestone;
  if (!shouldApplyDelayedCopy()) return milestone;

  const text = KIND_COPY[classification.kind];
  if (!helpsOrient(text, milestone.strength)) return milestone;

  recordDelayedCopy(classification.kind, text, milestone.id);
  return { ...milestone, text };
}

export function gateDelayedPayoffNote(
  entries: JournalEntry[],
  note: MemoryNote | null,
): MemoryNote | null {
  if (!note) return null;
  if (!passesDelayedPayoffGate(entries, note)) return null;
  return guardSurfacedNote(applyDelayedPayoffFraming(entries, note), entries, "delayed_payoff");
}

export function filterDelayedPayoffGate(
  entries: JournalEntry[],
  notes: MemoryNote[],
): MemoryNote[] {
  return notes
    .filter((note) => passesDelayedPayoffGate(entries, note))
    .map((note) => applyDelayedPayoffFraming(entries, note))
    .map((note) => guardSurfacedNote(note, entries, "delayed_payoff"))
    .filter((note): note is MemoryNote => note !== null);
}

export function gateDelayedPayoffMilestone(
  entries: JournalEntry[],
  milestone: EmotionalMilestone,
): EmotionalMilestone | null {
  if (!passesDelayedPayoffMilestoneGate(entries, milestone)) return null;
  return applyDelayedPayoffMilestoneFraming(entries, milestone);
}

export function filterDelayedPayoffMilestones(
  entries: JournalEntry[],
  milestones: EmotionalMilestone[],
): EmotionalMilestone[] {
  return milestones
    .filter((milestone) => passesDelayedPayoffMilestoneGate(entries, milestone))
    .map((milestone) => applyDelayedPayoffMilestoneFraming(entries, milestone));
}

function pushCandidate(
  bucket: DelayedPayoffCandidate[],
  item: Omit<DelayedPayoffCandidate, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < DELAYED_PAYOFF_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  if (item.gapDays < item.threshold) return;
  bucket.push({ ...item, strength });
}

function detectPhraseAbsentLongEnough(sorted: JournalEntry[]): DelayedPayoffCandidate[] {
  const notes: DelayedPayoffCandidate[] = [];
  const latest = sorted[sorted.length - 1];
  const phrases = buildPhraseMemory(sorted);

  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    const gap = daysBetweenKeys(lastOcc.dateKey, todayKey());
    if (gap < 30) continue;

    const priorEntry = sorted.find((row) => row.id === lastOcc.entryId);
    if (!priorEntry) continue;

    pushCandidate(notes, {
      id: `delayed-phrase-${record.phrase}`,
      kind: "phrase_absent",
      text: DELAYED_PAYOFF_COPY.feelsDifferentWithTime,
      threshold: 30,
      gapDays: gap,
      anchorEntryId: priorEntry.id,
      strength: 74 + Math.min(gap, 20),
      ...evidencePair(priorEntry, latest),
    });
  }

  return notes;
}

function detectConcernAbsentLongEnough(sorted: JournalEntry[]): DelayedPayoffCandidate[] {
  const notes: DelayedPayoffCandidate[] = [];
  const latest = sorted[sorted.length - 1];

  for (const theme of latest.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const themed = sorted.filter((row) =>
      row.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey),
    );
    if (themed.length < 2) continue;

    const lastThemed = themed[themed.length - 2];
    const gap = daysBetweenKeys(toDayKey(lastThemed.createdAt), toDayKey(latest.createdAt));
    if (gap < 30) continue;

    const intenseStretch = themed.slice(0, -1).some((row) => row.reflection.emotionalIntensity >= 6);
    const concernLanguage = themed.some((row) => countMatches(entryText(row), HEDGE_RE) >= 2);
    if (!intenseStretch && !concernLanguage) continue;

    pushCandidate(notes, {
      id: `delayed-concern-${themeKey}-${lastThemed.id}`,
      kind: "concern_absent",
      text: DELAYED_PAYOFF_COPY.hadToGetFurtherAway,
      threshold: 30,
      gapDays: gap,
      anchorEntryId: lastThemed.id,
      strength: 73 + Math.min(gap, 15),
      ...evidencePair(lastThemed, latest),
    });
  }

  return notes;
}

function detectContrastWidened(sorted: JournalEntry[]): DelayedPayoffCandidate[] {
  const notes: DelayedPayoffCandidate[] = [];

  for (const anchor of sorted.slice(0, -2)) {
    const later = sorted.filter(
      (row) => new Date(row.createdAt).getTime() > new Date(anchor.createdAt).getTime(),
    );
    const linked = later.filter((row) => sharedThemes(anchor, row).length > 0);
    if (linked.length < 2) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(linked[linked.length - 1].createdAt));
    const threshold = thresholdForGap(gap);
    if (gap < threshold) continue;

    const intensitySpread =
      anchor.reflection.emotionalIntensity -
      linked[linked.length - 1].reflection.emotionalIntensity;
    const directShift =
      countMatches(entryText(anchor), HEDGE_RE) >= 1 &&
      countMatches(entryText(linked[linked.length - 1]), DIRECT_RE) >= 1;

    if (Math.abs(intensitySpread) < 1.5 && !directShift) continue;

    pushCandidate(notes, {
      id: `delayed-contrast-${anchor.id}`,
      kind: "contrast_widened",
      text: DELAYED_PAYOFF_COPY.readsClearlyWithDistance,
      threshold,
      gapDays: gap,
      anchorEntryId: anchor.id,
      strength: 75 + Math.abs(intensitySpread) * 3 + (directShift ? 4 : 0),
      ...evidencePair(anchor, linked[linked.length - 1]),
    });
  }

  return notes;
}

function detectReadsDifferentlyLater(sorted: JournalEntry[]): DelayedPayoffCandidate[] {
  const notes: DelayedPayoffCandidate[] = [];

  for (const anchor of sorted.slice(0, -3)) {
    const later = sorted.filter(
      (row) => new Date(row.createdAt).getTime() > new Date(anchor.createdAt).getTime(),
    );
    const linked = later.filter((row) => sharedThemes(anchor, row).length > 0);
    if (linked.length < 2) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(linked[linked.length - 1].createdAt));
    const threshold: DelayedPayoffThreshold = gap >= 60 ? 60 : 30;
    if (gap < threshold) continue;

    const calmerLater = linked.some(
      (row) => row.reflection.emotionalIntensity <= anchor.reflection.emotionalIntensity - 1.5,
    );
    const directLater = linked.some(
      (row) => countMatches(entryText(row), DIRECT_RE) > countMatches(entryText(anchor), DIRECT_RE),
    );
    if (!calmerLater && !directLater) continue;

    pushCandidate(notes, {
      id: `delayed-reads-${anchor.id}`,
      kind: "reads_differently_later",
      text: DELAYED_PAYOFF_COPY.feelsDifferentWithTime,
      threshold,
      gapDays: gap,
      anchorEntryId: anchor.id,
      strength: 76 + linked.length * 2,
      ...evidencePair(anchor, linked[linked.length - 1]),
    });
  }

  return notes;
}

function detectRevisitedRelated(sorted: JournalEntry[]): DelayedPayoffCandidate[] {
  const notes: DelayedPayoffCandidate[] = [];
  if (!isBrowser()) return notes;

  for (const anchor of sorted.slice(0, -2)) {
    if (!hasRevisitedRelated(sorted, anchor.id)) continue;

    const later = sorted.filter(
      (row) => new Date(row.createdAt).getTime() > new Date(anchor.createdAt).getTime(),
    );
    if (later.length < 1) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(later[later.length - 1].createdAt));
    if (gap < 14) continue;

    pushCandidate(notes, {
      id: `delayed-revisited-${anchor.id}`,
      kind: "revisited_related",
      text: DELAYED_PAYOFF_COPY.readsClearlyWithDistance,
      threshold: 14,
      gapDays: gap,
      anchorEntryId: anchor.id,
      strength: 74 + Math.min(gap, 12),
      ...evidencePair(anchor, later[later.length - 1]),
    });
  }

  return notes;
}

/** Internal ranking — delayed payoff candidates that already meet distance thresholds. */
export function buildDelayedPayoffReport(entries: JournalEntry[]): DelayedPayoffReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const candidates = [
    ...detectPhraseAbsentLongEnough(sorted),
    ...detectConcernAbsentLongEnough(sorted),
    ...detectContrastWidened(sorted),
    ...detectReadsDifferentlyLater(sorted),
    ...detectRevisitedRelated(sorted),
  ]
    .sort((a, b) => b.strength - a.strength)
    .filter((note, index, list) => {
      const key = `${note.anchorEntryId}:${note.kind}`;
      return list.findIndex((row) => `${row.anchorEntryId}:${row.kind}` === key) === index;
    });

  return { candidates, hasData: candidates.length > 0 };
}

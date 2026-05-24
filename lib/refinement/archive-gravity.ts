import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { buildConversationThreadsReport } from "@/lib/memory/conversation-threads";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { buildRevisitWorthReport } from "@/lib/refinement/revisit-worth";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { gateDelayedPayoffNote } from "@/lib/memory/delayed-payoff";
import { formatRelativeDate } from "@/lib/utils";
import type { ConversationThread } from "@/types/conversation-thread";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type ArchiveGravityKind =
  | "returning_months"
  | "period_reads_differently"
  | "thread_worth_revisiting"
  | "older_entries_point_back"
  | "meaningful_after_change";

export type ArchiveGravitySurface = "homepage" | "memory" | "timeline" | "monthly";

export const ARCHIVE_GRAVITY_MIN = 72;
export const MIN_ARCHIVE_ENTRIES = 14;
export const MIN_SPAN_DAYS = 45;
export const TEXT_COOLDOWN_DAYS = 28;
export const SHOW_COOLDOWN_DAYS = 21;
export const MIN_SESSIONS_BETWEEN = 4;

export const ARCHIVE_GRAVITY_COPY = {
  returningMonths: "You have been returning to this for months.",
  periodReadsDifferently: "You were carrying this differently then.",
  threadWorthRevisiting: "You kept coming back to this.",
  olderEntriesPointBack: "Something older keeps pulling you back.",
} as const;

const GRAVITY_KEY = "voicememory_archive_gravity";

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely)\b/gi;

const SURFACE_KIND_PRIORITY: Record<ArchiveGravitySurface, ArchiveGravityKind[]> = {
  homepage: [
    "returning_months",
    "thread_worth_revisiting",
    "older_entries_point_back",
    "period_reads_differently",
    "meaningful_after_change",
  ],
  memory: [
    "older_entries_point_back",
    "period_reads_differently",
    "thread_worth_revisiting",
    "returning_months",
    "meaningful_after_change",
  ],
  timeline: [
    "returning_months",
    "period_reads_differently",
    "thread_worth_revisiting",
    "older_entries_point_back",
    "meaningful_after_change",
  ],
  monthly: [
    "period_reads_differently",
    "returning_months",
    "meaningful_after_change",
    "thread_worth_revisiting",
    "older_entries_point_back",
  ],
};

interface ArchiveGravityCandidate {
  id: string;
  kind: ArchiveGravityKind;
  text: string;
  strength: number;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  pastEntryId?: string;
  entryId?: string;
}

interface GravityState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: ArchiveGravitySurface;
    shownAt: number;
  }>;
}

export interface ArchiveGravityReport {
  candidates: ArchiveGravityCandidate[];
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

function monthKey(iso: string): string {
  return toDayKey(iso).slice(0, 7);
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
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
    ArchiveGravityCandidate,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function readState(): GravityState {
  if (!isBrowser()) {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
  try {
    const raw = localStorage.getItem(GRAVITY_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    return JSON.parse(raw) as GravityState;
  } catch {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
}

function writeState(state: GravityState): void {
  if (!isBrowser()) return;
  localStorage.setItem(GRAVITY_KEY, JSON.stringify(state));
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

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  const cutoff = Date.now() - TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
  return readState().records.some((row) => row.textKey === key && row.shownAt >= cutoff);
}

function shouldAllowShow(): boolean {
  const state = readState();
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS_BETWEEN) return false;
  if (daysSince(state.lastShownAt) < SHOW_COOLDOWN_DAYS) return false;
  return true;
}

function recordShown(candidate: ArchiveGravityCandidate, surface: ArchiveGravitySurface): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      noteId: candidate.id,
      textKey: textKey(candidate.text),
      surface,
      shownAt: now,
    },
  ].slice(-16);
  writeState(state);
}

function pushCandidate(
  bucket: ArchiveGravityCandidate[],
  item: Omit<ArchiveGravityCandidate, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < ARCHIVE_GRAVITY_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  if (isTextFatigued(item.text)) return;
  bucket.push({ ...item, strength });
}

function detectReturningMonths(
  sorted: JournalEntry[],
  threads: ConversationThread[],
): ArchiveGravityCandidate[] {
  const notes: ArchiveGravityCandidate[] = [];
  const today = todayKey();

  for (const thread of threads) {
    if (thread.mentionCount < 3) continue;

    const span = daysBetweenKeys(
      toDayKey(thread.firstAppearance),
      toDayKey(thread.latestAppearance),
    );
    if (span < 75) continue;

    const months = new Set(
      thread.entryIds
        .map((id) => sorted.find((entry) => entry.id === id))
        .filter(Boolean)
        .map((entry) => monthKey(entry!.createdAt)),
    );
    if (months.size < 3) continue;

    const latestGap = daysBetweenKeys(toDayKey(thread.latestAppearance), today);
    if (latestGap > 40) continue;

    const first = sorted.find((entry) => entry.id === thread.entryIds[0]);
    const last = sorted.find((entry) => entry.id === thread.entryIds[thread.entryIds.length - 1]);
    if (!first || !last) continue;

    pushCandidate(notes, {
      id: `archive-gravity-months-${thread.slug}`,
      kind: "returning_months",
      text: ARCHIVE_GRAVITY_COPY.returningMonths,
      strength: 74 + Math.min(Math.round(span / 15), 10) + Math.min(thread.mentionCount, 4),
      ...evidencePair(first, last),
    });
  }

  return notes;
}

function detectPeriodReadsDifferently(sorted: JournalEntry[]): ArchiveGravityCandidate[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const third = Math.max(3, Math.floor(sorted.length / 3));
  const early = sorted.slice(0, third);
  const recent = sorted.slice(-third);
  const earlyAvg = roundAvg(early.map((entry) => entry.reflection.emotionalIntensity));
  const recentAvg = roundAvg(recent.map((entry) => entry.reflection.emotionalIntensity));
  const earlyHedge = roundAvg(early.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
  const recentHedge = roundAvg(recent.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
  const earlyDirect = roundAvg(early.map((entry) => countMatches(entry.transcript, DIRECT_RE)));
  const recentDirect = roundAvg(recent.map((entry) => countMatches(entry.transcript, DIRECT_RE)));

  const span = daysBetweenKeys(
    toDayKey(early[early.length - 1].createdAt),
    toDayKey(recent[0].createdAt),
  );
  if (span < MIN_SPAN_DAYS) return [];

  const intensityShift = Math.abs(earlyAvg - recentAvg);
  const hedgeShift = earlyHedge - recentHedge;
  const directShift = recentDirect - earlyDirect;

  if (intensityShift < 1.2 && hedgeShift < 0.8 && directShift < 0.8) return [];

  return [
    (() => {
      const candidate: ArchiveGravityCandidate = {
        id: `archive-gravity-period-${recent[recent.length - 1].id}`,
        kind: "period_reads_differently",
        text: ARCHIVE_GRAVITY_COPY.periodReadsDifferently,
        strength:
          73 +
          Math.round(intensityShift * 4) +
          Math.round(Math.max(hedgeShift, 0) * 3) +
          Math.round(Math.max(directShift, 0) * 3),
        ...evidencePair(early[Math.floor(early.length / 2)], recent[recent.length - 1]),
      };
      return candidate;
    })(),
  ].filter((candidate) => {
    if (candidate.strength < ARCHIVE_GRAVITY_MIN) return false;
    if (!hasEvidence(candidate)) return false;
    if (isTextFatigued(candidate.text)) return false;
    return helpsOrient(candidate.text, candidate.strength);
  });
}

function detectThreadWorthRevisiting(
  sorted: JournalEntry[],
  threads: ConversationThread[],
): ArchiveGravityCandidate[] {
  const notes: ArchiveGravityCandidate[] = [];
  const worth = buildRevisitWorthReport(sorted);

  for (const thread of threads) {
    if (thread.mentionCount < 3) continue;

    const span = daysBetweenKeys(
      toDayKey(thread.firstAppearance),
      toDayKey(thread.latestAppearance),
    );
    if (span < 28) continue;

    const worthHits = thread.entryIds.filter((id) => worth.topEntryIds.includes(id));
    const hasEvolution = Boolean(
      thread.evolution.whatChanged || thread.evolution.whatCameBack,
    );
    if (worthHits.length === 0 && !hasEvolution) continue;

    const first = sorted.find((entry) => entry.id === thread.entryIds[0]);
    const last = sorted.find((entry) => entry.id === thread.entryIds[thread.entryIds.length - 1]);
    if (!first || !last) continue;

    pushCandidate(notes, {
      id: `archive-gravity-thread-${thread.slug}`,
      kind: "thread_worth_revisiting",
      text: ARCHIVE_GRAVITY_COPY.threadWorthRevisiting,
      strength:
        74 +
        worthHits.length * 4 +
        (hasEvolution ? 6 : 0) +
        Math.min(Math.round(span / 14), 8),
      ...evidencePair(first, last),
    });
  }

  return notes;
}

function detectOlderEntriesPointBack(sorted: JournalEntry[]): ArchiveGravityCandidate[] {
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return [];

  const latest = sorted[sorted.length - 1];
  const recent = sorted.slice(-2);
  let linkingOld = 0;
  let oldest: JournalEntry | null = null;
  const months = new Set<string>();

  for (const entry of sorted.slice(0, -2)) {
    const gap = daysBetweenKeys(toDayKey(entry.createdAt), toDayKey(latest.createdAt));
    if (gap < 21) continue;
    if (!recent.some((row) => sharedThemes(entry, row).length > 0)) continue;
    linkingOld += 1;
    months.add(monthKey(entry.createdAt));
    if (!oldest || new Date(entry.createdAt).getTime() < new Date(oldest.createdAt).getTime()) {
      oldest = entry;
    }
  }

  if (linkingOld < 3 || months.size < 2 || !oldest) return [];

  const notes: ArchiveGravityCandidate[] = [];
  pushCandidate(notes, {
    id: `archive-gravity-pointback-${latest.id}`,
    kind: "older_entries_point_back",
    text: ARCHIVE_GRAVITY_COPY.olderEntriesPointBack,
    strength: 73 + linkingOld * 2 + months.size * 2,
    ...evidencePair(oldest, latest),
  });

  return notes;
}

function detectMeaningfulAfterChange(sorted: JournalEntry[]): ArchiveGravityCandidate[] {
  const notes: ArchiveGravityCandidate[] = [];

  for (const entry of sorted.slice(0, -3)) {
    const bookmark = getBookmarkForEntry(entry.id);
    const summary = entryInteractionSummary(entry.id);
    const markedMeaningful =
      bookmark?.type === "changed_something" || (summary?.viewCount ?? 0) >= 2;
    if (!markedMeaningful) continue;

    const later = sorted.filter(
      (row) => new Date(row.createdAt).getTime() > new Date(entry.createdAt).getTime(),
    );
    const connectedLater = later.filter((row) => sharedThemes(entry, row).length > 0);
    if (connectedLater.length < 2) continue;

    const gap = daysBetweenKeys(toDayKey(entry.createdAt), toDayKey(later[later.length - 1].createdAt));
    if (gap < 30) continue;

    pushCandidate(notes, {
      id: `archive-gravity-meaning-${entry.id}`,
      kind: "meaningful_after_change",
      text: ARCHIVE_GRAVITY_COPY.olderEntriesPointBack,
      strength: 75 + connectedLater.length * 2 + (bookmark ? 4 : 0),
      ...evidencePair(entry, connectedLater[connectedLater.length - 1]),
    });
  }

  return notes;
}

function collectCandidates(
  sorted: JournalEntry[],
  surface: ArchiveGravitySurface,
): ArchiveGravityCandidate[] {
  const { threads } = buildConversationThreadsReport(sorted);
  const notes = [
    ...detectReturningMonths(sorted, threads),
    ...detectPeriodReadsDifferently(sorted),
    ...detectThreadWorthRevisiting(sorted, threads),
    ...detectOlderEntriesPointBack(sorted),
    ...detectMeaningfulAfterChange(sorted),
  ];

  const priority = SURFACE_KIND_PRIORITY[surface];
  const seen = new Set<string>();

  return notes
    .sort((a, b) => {
      const aPri = priority.indexOf(a.kind);
      const bPri = priority.indexOf(b.kind);
      if (aPri !== bPri) return aPri - bPri;
      return b.strength - a.strength;
    })
    .filter((note) => {
      const key = textKey(note.text);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function toMemoryNote(candidate: ArchiveGravityCandidate): MemoryNote {
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

function silenceSurface(surface: ArchiveGravitySurface): "homepage" | "memory" | "timeline" | "monthly" {
  return surface;
}

/** Internal ranking — all archive gravity candidates for a surface. */
export function buildArchiveGravityReport(
  entries: JournalEntry[],
  surface: ArchiveGravitySurface,
): ArchiveGravityReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const candidates = collectCandidates(sorted, surface);
  return {
    candidates,
    hasData: candidates.length > 0,
  };
}

/** Pick at most one rare archive gravity moment for a surface. */
export function pickArchiveGravityMoment(
  entries: JournalEntry[],
  surface: ArchiveGravitySurface,
): MemoryNote | null {
  touchSession();
  if (!shouldAllowShow()) return null;

  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ARCHIVE_ENTRIES) return null;

  const report = buildArchiveGravityReport(sorted, surface);
  const best = report.candidates[0];
  if (!best || best.strength < ARCHIVE_GRAVITY_MIN) return null;

  const calibrated = calibratePrimaryNote(
    [toMemoryNote(best)],
    sorted,
    silenceSurface(surface),
  );
  if (!calibrated) return null;

  recordShown(best, surface);
  return gateDelayedPayoffNote(sorted, calibrated);
}

export function homepageArchiveGravityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickArchiveGravityMoment(entries, "homepage");
}

export function memoryArchiveGravityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickArchiveGravityMoment(entries, "memory");
}

export function timelineArchiveGravityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickArchiveGravityMoment(entries, "timeline");
}

export function monthlyArchiveGravityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickArchiveGravityMoment(entries, "monthly");
}

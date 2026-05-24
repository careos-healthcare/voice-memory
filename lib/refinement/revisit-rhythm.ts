import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { trackLocalEvent } from "@/lib/local-analytics";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { filterRevisitCandidates } from "@/lib/refinement/revisit-sequencing";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import {
  buildRetentionLoopReport,
  type RetentionLoopEvent,
} from "@/lib/retention/retention-loops";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type RevisitRhythmKind =
  | "recent_revisit"
  | "revisit_to_reflection"
  | "revisit_kept_going"
  | "resurface_to_entry";

export type RevisitRhythmSurface = "homepage" | "memory";

export const REVISIT_RHYTHM_MIN = 70;
export const RECENT_REVISIT_DAYS = 7;
export const CHAIN_WINDOW_DAYS = 14;
export const SHOW_COOLDOWN_DAYS = 14;
export const TEXT_COOLDOWN_DAYS = 21;
export const MIN_SESSIONS_BETWEEN = 3;
export const MIN_ENTRIES = 4;

export const REVISIT_RHYTHM_COPY = {
  recentRevisit: "You came back to something important this week.",
  revisitToReflection: "You picked this back up.",
  revisitKeptGoing: "You returned here and kept going.",
  resurfaceThread: "You came back to the same place.",
} as const;

const RHYTHM_KEY = "voicememory_revisit_rhythm";
const RHYTHM_CONTEXT_KEY = "voicememory_revisit_rhythm_context";
const CONTEXT_TTL_MS = 1000 * 60 * 60 * 24;

const KIND_PRIORITY: RevisitRhythmKind[] = [
  "revisit_to_reflection",
  "revisit_kept_going",
  "resurface_to_entry",
  "recent_revisit",
];

const SURFACE_KIND_PRIORITY: Record<RevisitRhythmSurface, RevisitRhythmKind[]> = {
  homepage: KIND_PRIORITY,
  memory: ["revisit_to_reflection", "revisit_kept_going", "resurface_to_entry", "recent_revisit"],
};

interface RevisitRhythmCandidate {
  id: string;
  kind: RevisitRhythmKind;
  text: string;
  strength: number;
  entryId?: string;
  noteId?: string;
}

interface RhythmState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    kind: RevisitRhythmKind;
    shownAt: number;
  }>;
}

export interface RevisitRhythmReport {
  candidates: RevisitRhythmCandidate[];
  hasData: boolean;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function eventAgeDays(event: RetentionLoopEvent): number {
  return daysBetweenKeys(toDayKey(event.at), todayKey());
}

function withinDaysAfter(startIso: string, endIso: string, days: number): boolean {
  const start = new Date(startIso).getTime();
  const end = new Date(endIso).getTime();
  return end >= start && end - start <= days * 24 * 60 * 60 * 1000;
}

function revisitEntryId(event: RetentionLoopEvent): string | undefined {
  return event.entryId ?? event.pastEntryId ?? event.targetEntryId;
}

function readState(): RhythmState {
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
    const raw = localStorage.getItem(RHYTHM_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    return JSON.parse(raw) as RhythmState;
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

function writeState(state: RhythmState): void {
  if (!isBrowser()) return;
  localStorage.setItem(RHYTHM_KEY, JSON.stringify(state));
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

function recordShown(candidate: RevisitRhythmCandidate): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      noteId: candidate.id,
      textKey: textKey(candidate.text),
      kind: candidate.kind,
      shownAt: now,
    },
  ].slice(-12);
  writeState(state);
}

function pushCandidate(
  bucket: RevisitRhythmCandidate[],
  item: Omit<RevisitRhythmCandidate, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < REVISIT_RHYTHM_MIN) return;
  if (!helpsOrient(item.text, strength)) return;
  if (isTextFatigued(item.text)) return;
  bucket.push({ ...item, strength });
}

function detectRecentRevisits(events: RetentionLoopEvent[]): RevisitRhythmCandidate[] {
  const notes: RevisitRhythmCandidate[] = [];

  for (const event of events) {
    if (event.kind !== "entry_revisited") continue;
    const age = eventAgeDays(event);
    if (age > RECENT_REVISIT_DAYS) continue;
    const entryId = revisitEntryId(event);
    if (!entryId) continue;

    pushCandidate(notes, {
      id: `revisit-rhythm-recent-${entryId}-${event.id}`,
      kind: "recent_revisit",
      text: REVISIT_RHYTHM_COPY.recentRevisit,
      strength: 70 + (RECENT_REVISIT_DAYS - age) * 2,
      entryId,
      noteId: event.noteId,
    });
  }

  return notes;
}

function detectRevisitToReflection(
  events: RetentionLoopEvent[],
  report: ReturnType<typeof buildRetentionLoopReport>,
): RevisitRhythmCandidate[] {
  const notes: RevisitRhythmCandidate[] = [];
  const seen = new Set<string>();

  for (const link of report.revisitsCausingReflections) {
    if (!link.reflectionEntryId || !link.entryId) continue;
    const age = daysBetweenKeys(toDayKey(link.revisitedAt), todayKey());
    if (age > CHAIN_WINDOW_DAYS) continue;
    const key = `${link.entryId}:${link.reflectionEntryId}`;
    if (seen.has(key)) continue;
    seen.add(key);

    pushCandidate(notes, {
      id: `revisit-rhythm-reflect-${link.entryId}-${link.reflectionEntryId}`,
      kind: "revisit_to_reflection",
      text: REVISIT_RHYTHM_COPY.revisitToReflection,
      strength: 78 + Math.max(CHAIN_WINDOW_DAYS - age, 0),
      entryId: link.entryId,
      noteId: link.noteId,
    });
  }

  for (const revisit of events.filter((row) => row.kind === "entry_revisited")) {
    const entryId = revisitEntryId(revisit);
    if (!entryId) continue;
    if (eventAgeDays(revisit) > CHAIN_WINDOW_DAYS) continue;

    const reflection = events.find(
      (row) =>
        row.kind === "followup_recording_completed" &&
        withinDaysAfter(revisit.at, row.at, CHAIN_WINDOW_DAYS) &&
        (row.noteId === revisit.noteId || row.entryId),
    );
    if (!reflection) continue;

    const key = `${entryId}:${reflection.entryId ?? reflection.id}`;
    if (seen.has(key)) continue;
    seen.add(key);

    pushCandidate(notes, {
      id: `revisit-rhythm-followup-${entryId}-${reflection.id}`,
      kind: "revisit_to_reflection",
      text: REVISIT_RHYTHM_COPY.revisitToReflection,
      strength: 80 + Math.max(CHAIN_WINDOW_DAYS - eventAgeDays(revisit), 0),
      entryId,
      noteId: revisit.noteId ?? reflection.noteId,
    });
  }

  return notes;
}

function detectRevisitKeptGoing(events: RetentionLoopEvent[]): RevisitRhythmCandidate[] {
  const notes: RevisitRhythmCandidate[] = [];
  const revisitEvents = events.filter(
    (row) => row.kind === "entry_revisited" || row.kind === "old_entry_opened_from_note",
  );

  for (const revisit of revisitEvents) {
    const entryId = revisitEntryId(revisit);
    if (!entryId) continue;
    if (eventAgeDays(revisit) > CHAIN_WINDOW_DAYS) continue;

    const bookmark = events.find(
      (row) =>
        row.kind === "bookmark_created" &&
        row.entryId === entryId &&
        withinDaysAfter(revisit.at, row.at, CHAIN_WINDOW_DAYS),
    );
    const copied = events.find(
      (row) =>
        row.kind === "copied_memory_moment" &&
        withinDaysAfter(revisit.at, row.at, CHAIN_WINDOW_DAYS) &&
        (row.entryId === entryId || (revisit.noteId && row.noteId === revisit.noteId)),
    );

    if (!bookmark && !copied) continue;

    pushCandidate(notes, {
      id: `revisit-rhythm-kept-${entryId}-${revisit.id}`,
      kind: "revisit_kept_going",
      text: REVISIT_RHYTHM_COPY.revisitKeptGoing,
      strength: 76 + (bookmark ? 4 : 0) + (copied ? 3 : 0),
      entryId,
      noteId: revisit.noteId ?? bookmark?.noteId ?? copied?.noteId,
    });
  }

  return notes;
}

function detectResurfaceToEntry(events: RetentionLoopEvent[]): RevisitRhythmCandidate[] {
  const notes: RevisitRhythmCandidate[] = [];

  for (const event of events) {
    if (event.kind !== "old_entry_opened_from_note" && event.kind !== "resurfaced_memory_clicked") {
      continue;
    }
    const age = eventAgeDays(event);
    if (age > CHAIN_WINDOW_DAYS) continue;

    const entryId = revisitEntryId(event);
    if (!entryId || !event.noteId) continue;

    pushCandidate(notes, {
      id: `revisit-rhythm-resurface-${entryId}-${event.id}`,
      kind: "resurface_to_entry",
      text: REVISIT_RHYTHM_COPY.resurfaceThread,
      strength: 74 + Math.max(CHAIN_WINDOW_DAYS - age, 0),
      entryId,
      noteId: event.noteId,
    });
  }

  return notes;
}

function collectCandidates(
  report: ReturnType<typeof buildRetentionLoopReport>,
): RevisitRhythmCandidate[] {
  const events = report.events;
  const notes = [
    ...detectRevisitToReflection(events, report),
    ...detectRevisitKeptGoing(events),
    ...detectResurfaceToEntry(events),
    ...detectRecentRevisits(events),
  ];

  const seen = new Set<string>();
  return notes.filter((note) => {
    const key = `${note.kind}:${note.entryId ?? note.id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function sortCandidates(
  candidates: RevisitRhythmCandidate[],
  surface: RevisitRhythmSurface,
): RevisitRhythmCandidate[] {
  const priority = SURFACE_KIND_PRIORITY[surface];
  return [...candidates].sort((a, b) => {
    const aPri = priority.indexOf(a.kind);
    const bPri = priority.indexOf(b.kind);
    if (aPri !== bPri) return aPri - bPri;
    return b.strength - a.strength;
  });
}

function toMemoryNote(candidate: RevisitRhythmCandidate): MemoryNote {
  return {
    id: candidate.id,
    text: candidate.text,
    category: "returned",
    confidence: candidate.strength,
    entryId: candidate.entryId,
    pastEntryId: candidate.entryId,
  };
}

/** Rank revisit rhythm signals — debug and internal selection. */
export function buildRevisitRhythmReport(
  entries: JournalEntry[],
  surface: RevisitRhythmSurface = "homepage",
): RevisitRhythmReport {
  if (entries.length < MIN_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const loopReport = buildRetentionLoopReport();
  if (!loopReport.hasData) {
    return { candidates: [], hasData: false };
  }

  const candidates = sortCandidates(
    filterRevisitCandidates(collectCandidates(loopReport)),
    surface,
  );
  return {
    candidates,
    hasData: candidates.length > 0,
  };
}

/** Pick at most one sparse revisit rhythm line for a surface. */
export function pickRevisitRhythmMoment(
  entries: JournalEntry[],
  surface: RevisitRhythmSurface,
): MemoryNote | null {
  touchSession();
  if (!shouldAllowShow()) return null;

  const report = buildRevisitRhythmReport(entries, surface);
  const best = report.candidates[0];
  if (!best || best.strength < REVISIT_RHYTHM_MIN) return null;

  const calibrated = calibratePrimaryNote([toMemoryNote(best)], entries, surface);
  if (!calibrated) return null;

  recordShown(best);
  markRevisitRhythmShown(best.id, best.kind);
  return calibrated;
}

export function homepageRevisitRhythmMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickRevisitRhythmMoment(entries, "homepage");
}

export function memoryRevisitRhythmMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickRevisitRhythmMoment(entries, "memory");
}

export function markRevisitRhythmShown(noteId: string, kind: RevisitRhythmKind): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(
    RHYTHM_CONTEXT_KEY,
    JSON.stringify({ noteId, kind, at: Date.now() }),
  );
}

function readRhythmContext(): { noteId: string; kind: RevisitRhythmKind; at: number } | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(RHYTHM_CONTEXT_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { noteId: string; kind: RevisitRhythmKind; at: number };
    if (Date.now() - parsed.at > CONTEXT_TTL_MS) {
      sessionStorage.removeItem(RHYTHM_CONTEXT_KEY);
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function consumeRevisitRhythmContext(): { noteId: string; kind: RevisitRhythmKind } | null {
  const context = readRhythmContext();
  if (!context) return null;
  sessionStorage.removeItem(RHYTHM_CONTEXT_KEY);
  return { noteId: context.noteId, kind: context.kind };
}

export function trackRevisitRhythmSeen(noteId: string, kind: RevisitRhythmKind): void {
  trackLocalEvent("revisit_rhythm_seen", { noteId, kind });
}

export function trackRevisitRhythmFollowup(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_rhythm_followup", { entryId, promptId });
}

export function trackRevisitRhythmBookmark(entryId: string, bookmarkType: string): void {
  trackLocalEvent("revisit_rhythm_bookmark", { entryId, bookmarkType });
}

export function trackRevisitRhythmFollowupIfActive(entryId: string, promptId: string): void {
  const context = consumeRevisitRhythmContext();
  if (!context) return;
  trackRevisitRhythmFollowup(entryId || context.noteId, promptId);
}

export function trackRevisitRhythmBookmarkIfActive(
  entryId: string,
  bookmarkType: string,
): void {
  const context = consumeRevisitRhythmContext();
  if (!context) return;
  trackRevisitRhythmBookmark(entryId, bookmarkType);
}

export function revisitRhythmKindFromNote(note: MemoryNote): RevisitRhythmKind | null {
  if (!note.id.startsWith("revisit-rhythm-")) return null;
  if (note.id.includes("-reflect-") || note.id.includes("-followup-")) {
    return "revisit_to_reflection";
  }
  if (note.id.includes("-kept-")) return "revisit_kept_going";
  if (note.id.includes("-resurface-")) return "resurface_to_entry";
  if (note.id.includes("-recent-")) return "recent_revisit";
  return null;
}

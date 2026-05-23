import { toDayKey } from "@/lib/dates";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const TIMING_KEY = "voicememory_emotional_timing";
const MS_PER_HOUR = 1000 * 60 * 60;

export type EmotionalSurface =
  | "homepage"
  | "entry"
  | "memory"
  | "timeline"
  | "monthly"
  | "thread"
  | "bookmark";

interface TimingState {
  sessionDay: string;
  emotionalNotesThisSession: number;
  lastEmotionalAt: number;
  lastThemeKey: string;
  lastThemeAt: number;
  revisitBoostUntil: number;
  followupBoostUntil: number;
  heavyEntryBoostUntil: number;
  records: Array<{ noteId: string; textKey: string; surface: EmotionalSurface; shownAt: number }>;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readState(): TimingState {
  if (!isBrowser()) {
    return emptyState();
  }
  try {
    const raw = localStorage.getItem(TIMING_KEY);
    if (!raw) return emptyState();
    const parsed = JSON.parse(raw) as Partial<TimingState>;
    const today = toDayKey(new Date().toISOString());
    const sessionDay = parsed.sessionDay ?? "";
    if (sessionDay !== today) {
      return {
        ...emptyState(),
        sessionDay: today,
        revisitBoostUntil: parsed.revisitBoostUntil ?? 0,
        followupBoostUntil: parsed.followupBoostUntil ?? 0,
        heavyEntryBoostUntil: parsed.heavyEntryBoostUntil ?? 0,
      };
    }
    return {
      sessionDay: today,
      emotionalNotesThisSession: parsed.emotionalNotesThisSession ?? 0,
      lastEmotionalAt: parsed.lastEmotionalAt ?? 0,
      lastThemeKey: parsed.lastThemeKey ?? "",
      lastThemeAt: parsed.lastThemeAt ?? 0,
      revisitBoostUntil: parsed.revisitBoostUntil ?? 0,
      followupBoostUntil: parsed.followupBoostUntil ?? 0,
      heavyEntryBoostUntil: parsed.heavyEntryBoostUntil ?? 0,
      records: Array.isArray(parsed.records) ? parsed.records : [],
    };
  } catch {
    return emptyState();
  }
}

function emptyState(): TimingState {
  return {
    sessionDay: toDayKey(new Date().toISOString()),
    emotionalNotesThisSession: 0,
    lastEmotionalAt: 0,
    lastThemeKey: "",
    lastThemeAt: 0,
    revisitBoostUntil: 0,
    followupBoostUntil: 0,
    heavyEntryBoostUntil: 0,
    records: [],
  };
}

function writeState(state: TimingState): void {
  if (!isBrowser()) return;
  localStorage.setItem(TIMING_KEY, JSON.stringify(state));
}

function textKey(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 72);
}

function themeKey(note: MemoryNote): string {
  return textKey(note.text).slice(0, 32);
}

function hoursSince(timestamp: number): number {
  if (!timestamp) return Number.POSITIVE_INFINITY;
  return (Date.now() - timestamp) / MS_PER_HOUR;
}

export function markRevisitBoost(minutes = 45): void {
  const state = readState();
  state.revisitBoostUntil = Date.now() + minutes * 60 * 1000;
  writeState(state);
}

export function markFollowupBoost(minutes = 60): void {
  const state = readState();
  state.followupBoostUntil = Date.now() + minutes * 60 * 1000;
  writeState(state);
}

export function markHeavyEntryBoost(minutes = 90): void {
  const state = readState();
  state.heavyEntryBoostUntil = Date.now() + minutes * 60 * 1000;
  writeState(state);
}

export function isRevisitEntry(entryId: string): boolean {
  const summary = entryInteractionSummary(entryId);
  const bookmarked = Boolean(getBookmarkForEntry(entryId));
  return bookmarked || (summary?.viewCount ?? 0) > 1;
}

export function shouldAllowEmotionalNote(
  surface: EmotionalSurface,
  note: MemoryNote,
  options: { maxPerSession?: number; minHoursBetween?: number } = {},
): boolean {
  const maxPerSession = options.maxPerSession ?? (surface === "homepage" ? 1 : 2);
  const minHours = options.minHoursBetween ?? 3;
  const state = readState();
  const now = Date.now();
  const key = textKey(note.text);

  const recentSameText = state.records.some(
    (record) => record.textKey === key && now - record.shownAt < 1000 * 60 * 60 * 24 * 14,
  );
  if (recentSameText) return false;

  const theme = themeKey(note);
  if (state.lastThemeKey === theme && hoursSince(state.lastThemeAt) < 8) return false;

  if (state.emotionalNotesThisSession >= maxPerSession && surface === "homepage") {
    return false;
  }

  if (hoursSince(state.lastEmotionalAt) < minHours && surface === "homepage") {
    const boosted =
      now < state.revisitBoostUntil ||
      now < state.followupBoostUntil ||
      now < state.heavyEntryBoostUntil;
    if (!boosted) return false;
  }

  return true;
}

export function recordEmotionalNoteShown(
  surface: EmotionalSurface,
  note: MemoryNote,
): void {
  const state = readState();
  const now = Date.now();
  state.emotionalNotesThisSession += 1;
  state.lastEmotionalAt = now;
  state.lastThemeKey = themeKey(note);
  state.lastThemeAt = now;
  state.records = [
    ...state.records,
    {
      noteId: note.id,
      textKey: textKey(note.text),
      surface,
      shownAt: now,
    },
  ].slice(-40);
  writeState(state);
}

export function suppressResurfacingCluster(notes: MemoryNote[]): MemoryNote[] {
  if (notes.length <= 1) return notes;
  return [notes[0]];
}

export function entryFeelsHeavy(entry: JournalEntry): boolean {
  return entry.reflection.emotionalIntensity >= 7;
}

export function bumpTimingFromEntry(entry: JournalEntry): void {
  if (entryFeelsHeavy(entry)) markHeavyEntryBoost();
}

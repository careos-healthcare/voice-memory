import { toDayKey } from "@/lib/dates";
import { recordEmotionalNoteShown } from "@/lib/refinement/emotional-timing";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const SILENCE_KEY = "voicememory_silence_calibration";
const MS_PER_HOUR = 1000 * 60 * 60;
const MS_PER_DAY = MS_PER_HOUR * 24;

export const MIN_SHOW_SCORE = 64;
export const STRONG_NOTE_SCORE = 70;
export const STRONG_CONFIDENCE = 66;
export const SESSION_NOTE_MAX = 3;
export const FOLLOWUP_MIN_STRENGTH = 68;

export type SilenceSurface =
  | "homepage"
  | "entry"
  | "entry_revisit"
  | "timeline"
  | "monthly"
  | "memory";

export type EmotionalCategory =
  | "settled"
  | "direct"
  | "heavier_before"
  | "stopped_circling"
  | "return_timing"
  | "contrast"
  | "continuity"
  | "resurfacing"
  | "familiarity"
  | "recovery"
  | "revisit"
  | "milestone"
  | "other";

interface SilenceState {
  sessionDay: string;
  sessionNoteCount: number;
  followupsThisSession: number;
  recentCategories: Array<{ category: EmotionalCategory; at: number }>;
  recentTexts: Array<{ textKey: string; at: number }>;
  lastStrongNoteAt: number;
  lastFollowupAt: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function emptyState(): SilenceState {
  return {
    sessionDay: toDayKey(new Date().toISOString()),
    sessionNoteCount: 0,
    followupsThisSession: 0,
    recentCategories: [],
    recentTexts: [],
    lastStrongNoteAt: 0,
    lastFollowupAt: 0,
  };
}

function readState(): SilenceState {
  if (!isBrowser()) return emptyState();
  try {
    const raw = localStorage.getItem(SILENCE_KEY);
    if (!raw) return emptyState();
    const parsed = JSON.parse(raw) as Partial<SilenceState>;
    const today = toDayKey(new Date().toISOString());
    if (parsed.sessionDay !== today) {
      return {
        ...emptyState(),
        sessionDay: today,
        lastStrongNoteAt: parsed.lastStrongNoteAt ?? 0,
      };
    }
    return {
      sessionDay: today,
      sessionNoteCount: parsed.sessionNoteCount ?? 0,
      followupsThisSession: parsed.followupsThisSession ?? 0,
      recentCategories: Array.isArray(parsed.recentCategories) ? parsed.recentCategories : [],
      recentTexts: Array.isArray(parsed.recentTexts) ? parsed.recentTexts : [],
      lastStrongNoteAt: parsed.lastStrongNoteAt ?? 0,
      lastFollowupAt: parsed.lastFollowupAt ?? 0,
    };
  } catch {
    return emptyState();
  }
}

function writeState(state: SilenceState): void {
  if (!isBrowser()) return;
  localStorage.setItem(SILENCE_KEY, JSON.stringify(state));
}

function normalizeTextKey(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 72);
}

function hoursSince(timestamp: number): number {
  if (!timestamp) return Number.POSITIVE_INFINITY;
  return (Date.now() - timestamp) / MS_PER_HOUR;
}

/** Map a note to a coarse emotional category for session dedupe. */
export function classifyEmotionalCategory(note: MemoryNote): EmotionalCategory {
  const id = note.id;
  const text = note.text.toLowerCase();

  if (id.startsWith("familiar-") || id.startsWith("knows-me-")) {
    if (/settled|calmer|quieter/.test(text)) return "settled";
    if (/named|direct/.test(text)) return "direct";
    if (/heavier|pressure/.test(text)) return "heavier_before";
    if (/circling|stopped/.test(text)) return "stopped_circling";
    if (/longer|sooner|return|back/.test(text)) return "return_timing";
  }
  if (id.startsWith("rhythm-") || id.startsWith("time-")) return "return_timing";
  if (id.startsWith("tvn-") || id.startsWith("revisit-diff") || (note.pastQuote && note.currentQuote)) {
    return "contrast";
  }
  if (id.startsWith("continuity-")) return "continuity";
  if (id.startsWith("resurface-")) return "resurfacing";
  if (id.startsWith("fam-resurface-") || id.startsWith("familiarity-")) return "familiarity";
  if (id.startsWith("recovery-") || id.startsWith("moment-recovery-")) return "recovery";
  if (id.startsWith("milestone-")) return "milestone";
  if (id.startsWith("revisit-reward") || id.startsWith("revisit-")) return "revisit";
  if (id.startsWith("change-")) {
    if (/direct|named|hedge/.test(id)) return "direct";
    if (/charged|heavier|pressure/.test(text)) return "heavier_before";
    return "contrast";
  }
  if (/settled|calmer/.test(text)) return "settled";
  if (/named|direct/.test(text)) return "direct";
  if (/heavier|pressure/.test(text)) return "heavier_before";
  if (/circling/.test(text)) return "stopped_circling";
  if (/return|sooner|longer/.test(text)) return "return_timing";
  return "other";
}

export function isStrongNote(note: MemoryNote, entries: JournalEntry[]): boolean {
  const score = scoreMemoryHierarchy(note, entries).total;
  return score >= STRONG_NOTE_SCORE || note.confidence >= STRONG_CONFIDENCE + 2;
}

export function isWeakNote(note: MemoryNote, entries: JournalEntry[]): boolean {
  const score = scoreMemoryHierarchy(note, entries).total;
  return score < MIN_SHOW_SCORE - 4 && note.confidence < 62;
}

function requiredScore(state: SilenceState): number {
  if (state.lastStrongNoteAt && hoursSince(state.lastStrongNoteAt) < 12) {
    return STRONG_NOTE_SCORE + 2;
  }
  if (state.sessionNoteCount >= 1 && hoursSince(state.lastStrongNoteAt) < 4) {
    return MIN_SHOW_SCORE + 4;
  }
  return MIN_SHOW_SCORE;
}

function categoryShownThisSession(state: SilenceState, category: EmotionalCategory): boolean {
  return state.recentCategories.some((row) => row.category === category);
}

function textShownRecently(state: SilenceState, text: string): boolean {
  const key = normalizeTextKey(text);
  return state.recentTexts.some(
    (row) => row.textKey === key && Date.now() - row.at < MS_PER_DAY * 14,
  );
}

function inStrongNoteCooldown(state: SilenceState): boolean {
  return Boolean(state.lastStrongNoteAt && hoursSince(state.lastStrongNoteAt) < 6);
}

function surfaceSessionCap(surface: SilenceSurface): number {
  if (surface === "homepage" || surface === "entry" || surface === "entry_revisit") return 1;
  return 2;
}

function passesSilenceFilters(
  note: MemoryNote,
  entries: JournalEntry[],
  surface: SilenceSurface,
  state: SilenceState,
): boolean {
  if (isWeakNote(note, entries)) return false;

  const score = scoreMemoryHierarchy(note, entries).total;
  if (score < requiredScore(state)) return false;

  const category = classifyEmotionalCategory(note);
  if (categoryShownThisSession(state, category)) return false;
  if (textShownRecently(state, note.text)) return false;

  if (inStrongNoteCooldown(state) && !isStrongNote(note, entries)) return false;

  if (state.sessionNoteCount >= SESSION_NOTE_MAX && surface !== "entry_revisit") {
    return false;
  }

  if (state.sessionNoteCount >= surfaceSessionCap(surface) && surface !== "entry_revisit") {
    const cap = surfaceSessionCap(surface);
    if (cap === 1 && state.sessionNoteCount >= 1) {
      return isStrongNote(note, entries) && score >= STRONG_NOTE_SCORE + 4;
    }
  }

  return true;
}

function toEmotionalSurface(surface: SilenceSurface): "homepage" | "entry" | "timeline" | "monthly" | "memory" {
  if (surface === "entry_revisit") return "entry";
  return surface;
}

/** Record that a calibrated note was shown — updates local timing memory. */
export function recordSilenceShown(
  note: MemoryNote,
  entries: JournalEntry[],
  surface: SilenceSurface,
): void {
  const state = readState();
  const category = classifyEmotionalCategory(note);
  const textKey = normalizeTextKey(note.text);
  const strong = isStrongNote(note, entries);
  const now = Date.now();

  state.sessionNoteCount += 1;
  state.recentCategories = [...state.recentCategories, { category, at: now }].slice(-24);
  state.recentTexts = [...state.recentTexts, { textKey, at: now }].slice(-36);
  if (strong) state.lastStrongNoteAt = now;
  writeState(state);

  recordEmotionalNoteShown(toEmotionalSurface(surface), note);
}

function recordFollowupShown(): void {
  const state = readState();
  state.followupsThisSession += 1;
  state.lastFollowupAt = Date.now();
  writeState(state);
}

/** Pick at most one primary note that clears silence rules. */
export function calibratePrimaryNote(
  candidates: MemoryNote[],
  entries: JournalEntry[],
  surface: SilenceSurface,
): MemoryNote | null {
  if (candidates.length === 0) return null;

  const state = readState();
  const ranked = candidates
    .filter((note) => !isWeakNote(note, entries))
    .map((note) => ({ note, score: scoreMemoryHierarchy(note, entries).total }))
    .sort(
      (a, b) =>
        b.score - a.score || b.note.confidence - a.note.confidence,
    );

  if (ranked.length === 0 || ranked[0].score < MIN_SHOW_SCORE - 2) {
    return null;
  }

  for (const row of ranked) {
    if (!passesSilenceFilters(row.note, entries, surface, state)) continue;
    recordSilenceShown(row.note, entries, surface);
    return row.note;
  }

  return null;
}

/** Filter a note list down to strong, non-repetitive moments. */
export function calibrateMemoryNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
  surface: SilenceSurface,
  max = 1,
): MemoryNote[] {
  const picked: MemoryNote[] = [];
  const state = readState();

  const ranked = [...notes]
    .filter((note) => !isWeakNote(note, entries))
    .sort(
      (a, b) =>
        scoreMemoryHierarchy(b, entries).total - scoreMemoryHierarchy(a, entries).total ||
        b.confidence - a.confidence,
    );

  if (ranked.length === 0 || scoreMemoryHierarchy(ranked[0], entries).total < MIN_SHOW_SCORE - 2) {
    return [];
  }

  for (const note of ranked) {
    if (picked.length >= max) break;
    if (!passesSilenceFilters(note, entries, surface, readState())) continue;
    picked.push(note);
    recordSilenceShown(note, entries, surface);
    Object.assign(state, readState());
  }

  return picked;
}

/** Allow at most one follow-up prompt per session when evidence is strong. */
export function calibrateFollowupPrompt(
  prompt: FollowupPrompt | null,
  sourceNotes: MemoryNote[],
): FollowupPrompt | null {
  if (!prompt) return null;

  const state = readState();
  if (state.followupsThisSession >= 1) return null;
  if (prompt.strength < FOLLOWUP_MIN_STRENGTH) return null;

  const anchor = sourceNotes.find((note) => note.id === prompt.noteId);
  if (anchor && anchor.confidence < 62) return null;

  if (state.lastStrongNoteAt && hoursSince(state.lastStrongNoteAt) < 1.5) {
    return null;
  }

  if (state.lastFollowupAt && hoursSince(state.lastFollowupAt) < 8) {
    return null;
  }

  recordFollowupShown();
  return prompt;
}

/** Homepage — one primary note, prefer silence over filler. */
export function calibrateHomepagePresentation<
  T extends {
    primaryNote: MemoryNote | null;
    continuation: MemoryNote[];
    followupPrompt: FollowupPrompt | null;
  },
>(presentation: T, entries: JournalEntry[]): T {
  const candidates = presentation.primaryNote ? [presentation.primaryNote] : [];
  const primaryNote = calibratePrimaryNote(candidates, entries, "homepage");

  if (!primaryNote) {
    return {
      ...presentation,
      primaryNote: null,
      continuation: [],
      followupPrompt: null,
    };
  }

  return {
    ...presentation,
    primaryNote,
    continuation: [],
    followupPrompt: null,
  };
}

/** Entry first-view — one primary moment, no stacked callbacks. */
export function calibrateEntryPresentation<
  T extends {
    primaryMoment: MemoryNote | null;
    continuation: MemoryNote | null;
    followupPrompt: FollowupPrompt | null;
  },
>(presentation: T, entries: JournalEntry[]): T {
  const candidates = [
    ...(presentation.primaryMoment ? [presentation.primaryMoment] : []),
    ...(presentation.continuation ? [presentation.continuation] : []),
  ];

  const primaryMoment = calibratePrimaryNote(candidates, entries, "entry");

  if (!primaryMoment) {
    return {
      ...presentation,
      primaryMoment: null,
      continuation: null,
      followupPrompt: null,
    };
  }

  return {
    ...presentation,
    primaryMoment,
    continuation: null,
    followupPrompt: null,
  };
}

function hasContrastEvidence(note: MemoryNote): boolean {
  return Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
}

/** Revisit — reward line always visible; optional contrast when quotes exist. */
export function calibrateRevisitExperience<
  T extends {
    isRevisit: boolean;
    revisitReward: MemoryNote | null;
    thenVsNow: MemoryNote | null;
    followupPrompt: FollowupPrompt | null;
  },
>(experience: T, entries: JournalEntry[]): T {
  if (!experience.isRevisit) return experience;

  let revisitReward = experience.revisitReward;
  if (revisitReward?.text.trim()) {
    recordSilenceShown(revisitReward, entries, "entry_revisit");
  } else {
    revisitReward = null;
  }

  let thenVsNow = experience.thenVsNow;
  if (thenVsNow && hasContrastEvidence(thenVsNow) && !isWeakNote(thenVsNow, entries)) {
    recordSilenceShown(thenVsNow, entries, "entry_revisit");
  } else {
    thenVsNow = null;
  }

  if (!revisitReward && !thenVsNow) {
    return {
      ...experience,
      revisitReward: null,
      thenVsNow: null,
      followupPrompt: null,
    };
  }

  return {
    ...experience,
    revisitReward,
    thenVsNow,
    followupPrompt: null,
  };
}

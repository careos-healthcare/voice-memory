import { toDayKey } from "@/lib/dates";
import { recordEmotionalNoteShown } from "@/lib/refinement/emotional-timing";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const SILENCE_KEY = "voicememory_silence_calibration";
const MS_PER_HOUR = 1000 * 60 * 60;
const MS_PER_DAY = MS_PER_HOUR * 24;

export const MIN_SHOW_SCORE = 66;
export const STRONG_NOTE_SCORE = 72;
export const STRONG_CONFIDENCE = 68;
export const SESSION_NOTE_MAX = 2;
export const FOLLOWUP_MIN_STRENGTH = 70;

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

interface ShownNoteRecord {
  noteId: string;
  category: EmotionalCategory;
  at: number;
  actionTaken: boolean;
  strong: boolean;
}

interface SilenceState {
  sessionDay: string;
  sessionNoteCount: number;
  followupsThisSession: number;
  recentCategories: Array<{ category: EmotionalCategory; at: number }>;
  recentTexts: Array<{ textKey: string; at: number }>;
  lastStrongNoteAt: number;
  lastFollowupAt: number;
  lastHighActionAt: number;
  recentShown: ShownNoteRecord[];
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
    lastHighActionAt: 0,
    recentShown: [],
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
      lastHighActionAt: parsed.lastHighActionAt ?? 0,
      recentShown: Array.isArray(parsed.recentShown) ? parsed.recentShown : [],
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
    if (/settled|calmer|quieter|further away/.test(text)) return "settled";
    if (/named|direct/.test(text)) return "direct";
    if (/heavier|pressure|room/.test(text)) return "heavier_before";
    if (/circling|stopped/.test(text)) return "stopped_circling";
    if (/longer|sooner|return|back|same place/.test(text)) return "return_timing";
  }
  if (id.startsWith("rhythm-") || id.startsWith("time-")) return "return_timing";
  if (id.startsWith("tvn-") || id.startsWith("revisit-diff") || (note.pastQuote && note.currentQuote)) {
    return "contrast";
  }
  if (id.startsWith("continuity-") || id.startsWith("archive-gravity-")) return "continuity";
  if (id.startsWith("resurface-")) return "resurfacing";
  if (id.startsWith("fam-resurface-") || id.startsWith("familiarity-")) return "familiarity";
  if (id.startsWith("recovery-") || id.startsWith("moment-recovery-")) return "recovery";
  if (id.startsWith("milestone-")) return "milestone";
  if (id.startsWith("revisit-rhythm-")) return "revisit";
  if (id.startsWith("revisit-reward") || id.startsWith("revisit-")) return "revisit";
  if (id.startsWith("change-")) {
    if (/direct|named|hedge/.test(id)) return "direct";
    if (/charged|heavier|pressure|room/.test(text)) return "heavier_before";
    return "contrast";
  }
  if (/settled|calmer|further away/.test(text)) return "settled";
  if (/named|direct/.test(text)) return "direct";
  if (/heavier|pressure|room/.test(text)) return "heavier_before";
  if (/circling/.test(text)) return "stopped_circling";
  if (/return|sooner|longer|same place/.test(text)) return "return_timing";
  return "other";
}

export function isStrongNote(note: MemoryNote, entries: JournalEntry[]): boolean {
  const score = scoreMemoryHierarchy(note, entries).total;
  return score >= STRONG_NOTE_SCORE || note.confidence >= STRONG_CONFIDENCE + 2;
}

export function isWeakNote(note: MemoryNote, entries: JournalEntry[]): boolean {
  const score = scoreMemoryHierarchy(note, entries).total;
  return score < MIN_SHOW_SCORE - 2 && note.confidence < 64;
}

function consecutiveIgnoredCount(state: SilenceState): number {
  let count = 0;
  for (let i = state.recentShown.length - 1; i >= 0; i -= 1) {
    if (state.recentShown[i].actionTaken) break;
    count += 1;
  }
  return count;
}

function lastShownHadAction(state: SilenceState): boolean {
  const last = state.recentShown[state.recentShown.length - 1];
  return Boolean(last?.actionTaken);
}

function requiredScore(state: SilenceState, note: MemoryNote, category: EmotionalCategory): number {
  let base = MIN_SHOW_SCORE;

  if (state.lastHighActionAt && hoursSince(state.lastHighActionAt) < 4) {
    const lastAction = [...state.recentShown].reverse().find((row) => row.actionTaken);
    if (lastAction && lastAction.category === category) {
      base -= 6;
    } else if (lastAction) {
      base -= 3;
    }
  }

  if (state.lastStrongNoteAt && hoursSince(state.lastStrongNoteAt) < 8) {
    base += 4;
  }

  if (!lastShownHadAction(state) && state.recentShown.length > 0) {
    base += 5;
  }

  if (consecutiveIgnoredCount(state) >= 2) {
    base += 8;
  }

  return base;
}

function categoryShownThisSession(state: SilenceState, category: EmotionalCategory): boolean {
  if (state.lastHighActionAt && hoursSince(state.lastHighActionAt) < 3) {
    const lastAction = [...state.recentShown].reverse().find((row) => row.actionTaken);
    if (lastAction?.category === category) return false;
  }
  return state.recentCategories.some((row) => row.category === category);
}

function textShownRecently(state: SilenceState, text: string): boolean {
  const key = normalizeTextKey(text);
  return state.recentTexts.some(
    (row) => row.textKey === key && Date.now() - row.at < MS_PER_DAY * 14,
  );
}

function inStrongNoteCooldown(state: SilenceState): boolean {
  if (!state.lastStrongNoteAt) return false;
  const cooldownHours = lastShownHadAction(state) ? 4 : 10;
  return hoursSince(state.lastStrongNoteAt) < cooldownHours;
}

function surfaceSessionCap(surface: SilenceSurface): number {
  if (surface === "homepage" || surface === "entry" || surface === "entry_revisit") return 1;
  return 1;
}

function passesSilenceFilters(
  note: MemoryNote,
  entries: JournalEntry[],
  surface: SilenceSurface,
  state: SilenceState,
): boolean {
  if (isWeakNote(note, entries)) return false;

  if (consecutiveIgnoredCount(state) >= 2 && isWeakNote(note, entries)) return false;
  if (consecutiveIgnoredCount(state) >= 2 && !isStrongNote(note, entries)) {
    const score = scoreMemoryHierarchy(note, entries).total;
    if (score < STRONG_NOTE_SCORE) return false;
  }

  const category = classifyEmotionalCategory(note);
  const score = scoreMemoryHierarchy(note, entries).total;
  if (score < requiredScore(state, note, category)) return false;

  if (categoryShownThisSession(state, category)) return false;
  if (textShownRecently(state, note.text)) return false;

  if (inStrongNoteCooldown(state) && !isStrongNote(note, entries)) return false;

  if (state.sessionNoteCount >= SESSION_NOTE_MAX && surface !== "entry_revisit") {
    return false;
  }

  if (state.sessionNoteCount >= surfaceSessionCap(surface) && surface !== "entry_revisit") {
    if (!isStrongNote(note, entries) || score < STRONG_NOTE_SCORE + 2) {
      return false;
    }
  }

  return true;
}

function toEmotionalSurface(surface: SilenceSurface): "homepage" | "entry" | "timeline" | "monthly" | "memory" {
  if (surface === "entry_revisit") return "entry";
  return surface;
}

/** Mark engagement on a recently shown note — unlocks related follow-ups sooner. */
export function recordSilenceNoteAction(noteId: string): void {
  if (!isBrowser() || !noteId) return;
  const state = readState();
  const now = Date.now();
  let matched = false;

  state.recentShown = state.recentShown.map((row) => {
    if (row.noteId === noteId || noteId.startsWith(row.noteId)) {
      matched = true;
      return { ...row, actionTaken: true };
    }
    return row;
  });

  if (matched) {
    state.lastHighActionAt = now;
    writeState(state);
  }
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
  state.recentShown = [
    ...state.recentShown,
    { noteId: note.id, category, at: now, actionTaken: false, strong },
  ].slice(-12);
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
    if (!passesSilenceFilters(row.note, entries, surface, readState())) continue;
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
  if (anchor && anchor.confidence < 64) return null;

  if (state.lastHighActionAt && hoursSince(state.lastHighActionAt) < 6) {
    recordFollowupShown();
    return prompt;
  }

  if (state.lastStrongNoteAt && hoursSince(state.lastStrongNoteAt) < 1) {
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

function hasStrongRevisitReward(note: MemoryNote, entries: JournalEntry[]): boolean {
  return (
    Boolean(note.text.trim()) &&
    !isWeakNote(note, entries) &&
    scoreMemoryHierarchy(note, entries).total >= 58
  );
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

  const hasContrast =
    experience.thenVsNow &&
    hasContrastEvidence(experience.thenVsNow) &&
    !isWeakNote(experience.thenVsNow, entries);

  let thenVsNow = hasContrast ? experience.thenVsNow : null;
  if (thenVsNow) {
    recordSilenceShown(thenVsNow, entries, "entry_revisit");
  }

  let revisitReward = experience.revisitReward;
  if (thenVsNow) {
    revisitReward = null;
  } else if (revisitReward && hasStrongRevisitReward(revisitReward, entries)) {
    recordSilenceShown(revisitReward, entries, "entry_revisit");
  } else {
    revisitReward = null;
  }

  if (!revisitReward && !thenVsNow) {
    return {
      ...experience,
      revisitReward: null,
      thenVsNow: null,
      followupPrompt: null,
    };
  }

  const followupPrompt = calibrateFollowupPrompt(
    experience.followupPrompt,
    [revisitReward, thenVsNow].filter(Boolean) as MemoryNote[],
  );

  return {
    ...experience,
    revisitReward,
    thenVsNow,
    followupPrompt,
  };
}

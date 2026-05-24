import { toDayKey } from "@/lib/dates";
import { isFalsePositiveNote } from "@/lib/refinement/false-positive-suppression";
import { recordEmotionalNoteShown } from "@/lib/refinement/emotional-timing";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import {
  markSilenceIntelligenceSuppressed,
  shouldSuppressSilenceIntelligenceSurface,
} from "@/lib/restraint/silence-intelligence";
import {
  SCORE_SHOW as MIN_SHOW_SCORE,
  SCORE_STRONG as STRONG_NOTE_SCORE,
} from "@/lib/refinement/score-thresholds";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const SILENCE_KEY = "voicememory_silence_calibration";
const MS_PER_HOUR = 1000 * 60 * 60;
const MS_PER_DAY = MS_PER_HOUR * 24;
const IGNORED_COOLDOWN_HOURS = 36;
const HIGH_DWELL_MS = 6000;
const DELAY_CATEGORY_HOURS = 12;
const HIGH_DWELL_DELAY_HOURS = 12;

export { MIN_SHOW_SCORE, STRONG_NOTE_SCORE };
export const STRONG_CONFIDENCE = 68;
export const SESSION_NOTE_MAX = 1;
export const FOLLOWUP_MIN_STRENGTH = 70;

export type RelatedAllowanceReason =
  | "old_entry_open"
  | "recording_after_revisit"
  | "bookmark_copy";

const RELATED_ALLOWANCE: Record<
  RelatedAllowanceReason,
  { categories: EmotionalCategory[]; hours: number }
> = {
  old_entry_open: {
    categories: ["continuity", "revisit", "resurfacing", "contrast"],
    hours: 6,
  },
  recording_after_revisit: {
    categories: ["continuity", "revisit", "contrast"],
    hours: 8,
  },
  bookmark_copy: {
    categories: ["revisit", "contrast", "continuity"],
    hours: 6,
  },
};

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
  dwellMs?: number;
  highDwellNoAction?: boolean;
}

interface RelatedNoteAllowance {
  anchorCategory: EmotionalCategory;
  categories: EmotionalCategory[];
  until: number;
  reason: RelatedAllowanceReason;
}

interface DelayedCategory {
  category: EmotionalCategory;
  until: number;
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
  ignoredCooldownUntil: number;
  relatedNoteAllowance: RelatedNoteAllowance | null;
  delayedCategories: DelayedCategory[];
  recentShown: ShownNoteRecord[];
}

export interface SilenceTimingDebugSnapshot {
  ignoredCooldownActive: boolean;
  ignoredCooldownUntil: string | null;
  consecutiveIgnored: number;
  lastTwoWithoutEngagement: boolean;
  weakNoteSuppressed: boolean;
  highActionUnlockActive: boolean;
  highActionUnlockHoursAgo: number | null;
  relatedNoteAllowance: {
    reason: RelatedAllowanceReason;
    categories: EmotionalCategory[];
    expiresAt: string;
  } | null;
  delayedCategories: Array<{ category: EmotionalCategory; expiresAt: string }>;
  sessionNoteCount: number;
  recentShown: Array<{
    noteId: string;
    category: EmotionalCategory;
    actionTaken: boolean;
    highDwellNoAction: boolean;
    strong: boolean;
    shownAt: string;
  }>;
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
    ignoredCooldownUntil: 0,
    relatedNoteAllowance: null,
    delayedCategories: [],
    recentShown: [],
  };
}

function pruneDelayedCategories(rows: DelayedCategory[]): DelayedCategory[] {
  const now = Date.now();
  return rows.filter((row) => row.until > now);
}

function pruneRelatedAllowance(
  allowance: RelatedNoteAllowance | null,
): RelatedNoteAllowance | null {
  if (!allowance) return null;
  return allowance.until > Date.now() ? allowance : null;
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
        lastHighActionAt: parsed.lastHighActionAt ?? 0,
        ignoredCooldownUntil: parsed.ignoredCooldownUntil ?? 0,
        relatedNoteAllowance: pruneRelatedAllowance(
          (parsed.relatedNoteAllowance as RelatedNoteAllowance | null) ?? null,
        ),
        delayedCategories: pruneDelayedCategories(
          Array.isArray(parsed.delayedCategories)
            ? (parsed.delayedCategories as DelayedCategory[])
            : [],
        ),
        recentShown: Array.isArray(parsed.recentShown)
          ? (parsed.recentShown as ShownNoteRecord[]).slice(-12)
          : [],
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
      ignoredCooldownUntil: parsed.ignoredCooldownUntil ?? 0,
      relatedNoteAllowance: pruneRelatedAllowance(
        (parsed.relatedNoteAllowance as RelatedNoteAllowance | null) ?? null,
      ),
      delayedCategories: pruneDelayedCategories(
        Array.isArray(parsed.delayedCategories)
          ? (parsed.delayedCategories as DelayedCategory[])
          : [],
      ),
      recentShown: Array.isArray(parsed.recentShown)
        ? (parsed.recentShown as ShownNoteRecord[]).slice(-12)
        : [],
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

function lastTwoShownWithoutEngagement(state: SilenceState): boolean {
  const recent = state.recentShown.slice(-2);
  if (recent.length < 2) return false;
  return recent.every((row) => !row.actionTaken);
}

function ignoredCooldownActive(state: SilenceState): boolean {
  return state.ignoredCooldownUntil > Date.now();
}

function syncIgnoredCooldown(state: SilenceState): void {
  if (!lastTwoShownWithoutEngagement(state)) return;
  const until = Date.now() + IGNORED_COOLDOWN_HOURS * MS_PER_HOUR;
  if (until > state.ignoredCooldownUntil) {
    state.ignoredCooldownUntil = until;
  }
}

function categoryForNoteId(noteId: string, state: SilenceState): EmotionalCategory {
  const shown = state.recentShown.find(
    (row) => row.noteId === noteId || noteId.startsWith(row.noteId),
  );
  if (shown) return shown.category;
  return classifyEmotionalCategory({
    id: noteId,
    text: "",
    category: "changed",
    confidence: 0,
  });
}

function relatedAllowanceActive(
  state: SilenceState,
  category: EmotionalCategory,
): boolean {
  const allowance = pruneRelatedAllowance(state.relatedNoteAllowance);
  if (!allowance) return false;
  return allowance.categories.includes(category);
}

function categoryDelayed(state: SilenceState, category: EmotionalCategory): boolean {
  return state.delayedCategories.some(
    (row) => row.category === category && row.until > Date.now(),
  );
}

function delayCategory(state: SilenceState, category: EmotionalCategory): void {
  const until = Date.now() + HIGH_DWELL_DELAY_HOURS * MS_PER_HOUR;
  const without = state.delayedCategories.filter((row) => row.category !== category);
  state.delayedCategories = [...without, { category, until }];
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

  if (relatedAllowanceActive(state, category)) {
    base -= 8;
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

  if (lastTwoShownWithoutEngagement(state)) {
    base += 10;
  }

  if (ignoredCooldownActive(state)) {
    base += 12;
  }

  return base;
}

function categoryShownThisSession(state: SilenceState, category: EmotionalCategory): boolean {
  if (relatedAllowanceActive(state, category)) return false;
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

  const category = classifyEmotionalCategory(note);
  const score = scoreMemoryHierarchy(note, entries).total;
  const strong = isStrongNote(note, entries);
  const isStrongContrast =
    category === "contrast" &&
    (strong || Boolean(note.pastQuote?.trim() && note.currentQuote?.trim()));

  if (ignoredCooldownActive(state)) {
    if (isWeakNote(note, entries)) return false;
    if (!strong && !isStrongContrast && !relatedAllowanceActive(state, category)) {
      return false;
    }
  }

  if (lastTwoShownWithoutEngagement(state)) {
    if (!strong && !isStrongContrast && !relatedAllowanceActive(state, category)) {
      return false;
    }
  }

  if (categoryDelayed(state, category)) {
    if (!isStrongContrast) return false;
  }

  if (consecutiveIgnoredCount(state) >= 2 && !strong && !isStrongContrast) {
    if (score < STRONG_NOTE_SCORE) return false;
  }

  if (score < requiredScore(state, note, category)) return false;

  if (categoryShownThisSession(state, category)) return false;
  if (textShownRecently(state, note.text)) return false;

  if (inStrongNoteCooldown(state) && !strong) return false;

  if (state.sessionNoteCount >= SESSION_NOTE_MAX && surface !== "entry_revisit") {
    return false;
  }

  if (state.sessionNoteCount >= surfaceSessionCap(surface) && surface !== "entry_revisit") {
    if (!strong || score < STRONG_NOTE_SCORE + 2) {
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
      return { ...row, actionTaken: true, highDwellNoAction: false };
    }
    return row;
  });

  if (matched) {
    state.lastHighActionAt = now;
    writeState(state);
  }
}

/** Allow one related note sooner after a high-intent action on a memory line. */
export function unlockRelatedNoteAfterAction(
  noteId: string,
  reason: RelatedAllowanceReason,
): void {
  if (!isBrowser() || !noteId) return;
  const state = readState();
  const anchorCategory = categoryForNoteId(noteId, state);
  const config = RELATED_ALLOWANCE[reason];
  state.relatedNoteAllowance = {
    anchorCategory,
    categories: config.categories,
    until: Date.now() + config.hours * MS_PER_HOUR,
    reason,
  };
  writeState(state);
}

/** High dwell without action — delay similar notes, still allow strong contrast. */
export function recordSilenceNoteDwell(noteId: string, dwellMs: number): void {
  if (!isBrowser() || !noteId || dwellMs < HIGH_DWELL_MS) return;
  const state = readState();
  let matched = false;

  state.recentShown = state.recentShown.map((row) => {
    if (row.noteId !== noteId && !noteId.startsWith(row.noteId)) return row;
    if (row.actionTaken) return row;
    matched = true;
    return {
      ...row,
      dwellMs: Math.max(row.dwellMs ?? 0, dwellMs),
      highDwellNoAction: true,
    };
  });

  if (matched) {
    const category = categoryForNoteId(noteId, state);
    delayCategory(state, category);
    syncIgnoredCooldown(state);
    writeState(state);
  }
}

export function buildSilenceTimingDebugSnapshot(): SilenceTimingDebugSnapshot {
  const state = readState();
  syncIgnoredCooldown(state);
  state.relatedNoteAllowance = pruneRelatedAllowance(state.relatedNoteAllowance);
  state.delayedCategories = pruneDelayedCategories(state.delayedCategories);
  writeState(state);
  const allowance = state.relatedNoteAllowance;

  return {
    ignoredCooldownActive: ignoredCooldownActive(state),
    ignoredCooldownUntil:
      state.ignoredCooldownUntil > Date.now()
        ? new Date(state.ignoredCooldownUntil).toISOString()
        : null,
    consecutiveIgnored: consecutiveIgnoredCount(state),
    lastTwoWithoutEngagement: lastTwoShownWithoutEngagement(state),
    weakNoteSuppressed:
      ignoredCooldownActive(state) || lastTwoShownWithoutEngagement(state),
    highActionUnlockActive:
      Boolean(state.lastHighActionAt) && hoursSince(state.lastHighActionAt) < 6,
    highActionUnlockHoursAgo:
      state.lastHighActionAt > 0
        ? Math.round(hoursSince(state.lastHighActionAt) * 10) / 10
        : null,
    relatedNoteAllowance: allowance
      ? {
          reason: allowance.reason,
          categories: allowance.categories,
          expiresAt: new Date(allowance.until).toISOString(),
        }
      : null,
    delayedCategories: pruneDelayedCategories(state.delayedCategories).map((row) => ({
      category: row.category,
      expiresAt: new Date(row.until).toISOString(),
    })),
    sessionNoteCount: state.sessionNoteCount,
    recentShown: state.recentShown.map((row) => ({
      noteId: row.noteId,
      category: row.category,
      actionTaken: row.actionTaken,
      highDwellNoAction: Boolean(row.highDwellNoAction),
      strong: row.strong,
      shownAt: new Date(row.at).toISOString(),
    })),
  };
}

export function clearSilenceCalibrationState(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(SILENCE_KEY);
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
  syncIgnoredCooldown(state);
  state.relatedNoteAllowance = pruneRelatedAllowance(state.relatedNoteAllowance);
  state.delayedCategories = pruneDelayedCategories(state.delayedCategories);
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

  if (shouldSuppressSilenceIntelligenceSurface("memory_note")) {
    markSilenceIntelligenceSuppressed();
    return null;
  }

  const state = readState();
  const ranked = candidates
    .filter((note) => !isWeakNote(note, entries))
    .filter((note) => !isFalsePositiveNote(note, entries))
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
  if (shouldSuppressSilenceIntelligenceSurface("memory_note")) {
    markSilenceIntelligenceSuppressed();
    return [];
  }

  const picked: MemoryNote[] = [];

  const ranked = [...notes]
    .filter((note) => !isWeakNote(note, entries))
    .filter((note) => !isFalsePositiveNote(note, entries))
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

  if (shouldSuppressSilenceIntelligenceSurface("followup")) {
    markSilenceIntelligenceSuppressed();
    return null;
  }

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
  if (!note.text.trim()) return false;
  if (note.id.startsWith("revisit-reward-")) return true;
  return (
    !isWeakNote(note, entries) &&
    scoreMemoryHierarchy(note, entries).total >= 58
  );
}

/** Revisit — reward line + optional contrast; no filler without evidence. */
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
  if (revisitReward?.text.trim() && hasStrongRevisitReward(revisitReward, entries)) {
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

/** Signals for false-positive suppression — recent show + ignored similar notes. */
export function readFalsePositiveSilenceContext(
  text: string,
  noteId?: string,
): { shownRecently: boolean; ignoredSimilarBefore: boolean } {
  const state = readState();
  const shownRecently = textShownRecently(state, text);

  const similarIgnored =
    state.recentShown.some(
      (row) =>
        !row.actionTaken &&
        (row.noteId === noteId ||
          normalizeTextKey(text).length > 8 &&
          row.noteId.startsWith(noteId?.slice(0, 12) ?? "___")),
    ) && consecutiveIgnoredCount(state) >= 1;

  return {
    shownRecently,
    ignoredSimilarBefore:
      ignoredCooldownActive(state) ||
      lastTwoShownWithoutEngagement(state) ||
      similarIgnored,
  };
}

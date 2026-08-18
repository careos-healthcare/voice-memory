import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import {
  directCount,
  entrySnippet,
  hedgeCount,
} from "@/lib/memory/language-fingerprint";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { guardSurfacedNote } from "@/lib/refinement/false-positive-suppression";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export type VoiceIdentityKind =
  | "more_certain"
  | "more_direct"
  | "stopped_apologising"
  | "pause_less"
  | "self_language_shift";

export type VoiceIdentitySurface = "entry" | "timeline" | "monthly";

export const VOICE_IDENTITY_COPY = {
  moreCertain: "You sound more certain now.",
  moreDirect: "You speak about this more directly now.",
  stoppedApologising: "You stopped apologising here.",
  pauseLess: "You pause around this less now.",
  selfLanguageShift: "You speak differently about yourself now.",
} as const;

export const VOICE_ENTRY_MIN = 68;
export const VOICE_SURFACE_MIN = 76;
export const MIN_ENTRIES = 6;
export const MIN_GAP_DAYS = 14;
export const MIN_RECORDING_SECONDS = 12;
export const SHOW_COOLDOWN_DAYS = 21;
export const TEXT_COOLDOWN_DAYS = 28;
export const MIN_SESSIONS_BETWEEN = 4;

const STATE_KEY = "voicememory_voice_identity";

const CERTAINTY_RE =
  /\b(for sure|definitely|clearly|i know|certain|no doubt|without question|i decided)\b/gi;
const APOLOGY_RE = /\b(sorry|apolog\w*)\b/gi;
const SELF_RE = /\b(i am|i'm|myself|my own|the way i|who i am|i feel like i)\b/gi;
const LOOP_RE = /\b(same loop|keep coming back|circling|around it|again and again)\b/i;

const KIND_COPY: Record<VoiceIdentityKind, string> = {
  more_certain: VOICE_IDENTITY_COPY.moreCertain,
  more_direct: VOICE_IDENTITY_COPY.moreDirect,
  stopped_apologising: VOICE_IDENTITY_COPY.stoppedApologising,
  pause_less: VOICE_IDENTITY_COPY.pauseLess,
  self_language_shift: VOICE_IDENTITY_COPY.selfLanguageShift,
};

interface VoiceIdentityCandidate {
  id: string;
  kind: VoiceIdentityKind;
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

interface VoiceState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: VoiceIdentitySurface;
    shownAt: number;
  }>;
}

export interface VoiceIdentityReport {
  candidates: VoiceIdentityCandidate[];
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

function wordCount(entry: JournalEntry): number {
  return entry.transcript.trim().split(/\s+/).filter(Boolean).length;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function certaintyCount(entry: JournalEntry): number {
  return countMatches(entry.transcript, CERTAINTY_RE);
}

function apologyCount(entry: JournalEntry): number {
  return countMatches(entry.transcript, APOLOGY_RE);
}

function selfLanguageCount(entry: JournalEntry): number {
  return countMatches(entry.transcript, SELF_RE);
}

/** Transcript pacing approximation — not clinical voice analysis. */
export function wordsPerMinute(entry: JournalEntry): number | null {
  if (entry.durationSeconds < MIN_RECORDING_SECONDS) return null;
  const words = wordCount(entry);
  if (words < 10) return null;
  return Math.round((words / entry.durationSeconds) * 60);
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
    VoiceIdentityCandidate,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function readState(): VoiceState {
  const empty: VoiceState = {
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
    return JSON.parse(raw) as VoiceState;
  } catch {
    return empty;
  }
}

function writeState(state: VoiceState): void {
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

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  const cutoff = Date.now() - TEXT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
  return readState().records.some((row) => row.textKey === key && row.shownAt >= cutoff);
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function shouldAllowSurfaceShow(): boolean {
  const state = readState();
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS_BETWEEN) return false;
  if (daysSince(state.lastShownAt) < SHOW_COOLDOWN_DAYS) return false;
  return true;
}

function recordShown(candidate: VoiceIdentityCandidate, surface: VoiceIdentitySurface): void {
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
  bucket: VoiceIdentityCandidate[],
  item: Omit<VoiceIdentityCandidate, "strength"> & { strength?: number },
  minStrength: number,
): void {
  const strength = item.strength ?? 55;
  if (strength < minStrength) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function medianWpm(entries: JournalEntry[]): number | null {
  const values = entries.map(wordsPerMinute).filter((v): v is number => v !== null);
  if (values.length < 3) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function detectMoreCertain(
  anchor: JournalEntry,
  compare: JournalEntry,
  gap: number,
): VoiceIdentityCandidate | null {
  const certaintyGain = certaintyCount(compare) - certaintyCount(anchor);
  const hedgeDrop = hedgeCount(anchor) - hedgeCount(compare);
  if (certaintyGain < 1 && hedgeDrop < 1) return null;
  if (certaintyCount(compare) < 1 && hedgeDrop < 2) return null;

  return {
    id: `voice-certain-${anchor.id}-${compare.id}`,
    kind: "more_certain",
    text: KIND_COPY.more_certain,
    anchorEntryId: anchor.id,
    strength: 70 + certaintyGain * 4 + Math.max(hedgeDrop, 0) * 3 + Math.min(gap, 10),
    ...evidencePair(anchor, compare),
  };
}

function detectMoreDirect(
  anchor: JournalEntry,
  compare: JournalEntry,
  gap: number,
): VoiceIdentityCandidate | null {
  const directGain = directCount(compare) - directCount(anchor);
  const hedgeDrop = hedgeCount(anchor) - hedgeCount(compare);
  if (directGain < 1 && hedgeDrop < 2) return null;
  if (directCount(compare) < 1) return null;

  return {
    id: `voice-direct-${anchor.id}-${compare.id}`,
    kind: "more_direct",
    text: KIND_COPY.more_direct,
    anchorEntryId: anchor.id,
    strength: 72 + directGain * 4 + hedgeDrop * 2 + Math.min(gap, 8),
    ...evidencePair(anchor, compare),
  };
}

function detectStoppedApologising(
  anchor: JournalEntry,
  compare: JournalEntry,
  gap: number,
): VoiceIdentityCandidate | null {
  if (apologyCount(anchor) < 1) return null;
  if (apologyCount(compare) > 0) return null;

  return {
    id: `voice-apology-${anchor.id}-${compare.id}`,
    kind: "stopped_apologising",
    text: KIND_COPY.stopped_apologising,
    anchorEntryId: anchor.id,
    strength: 74 + apologyCount(anchor) * 3 + Math.min(gap, 10),
    ...evidencePair(anchor, compare),
  };
}

function detectPauseLess(
  anchor: JournalEntry,
  compare: JournalEntry,
  sorted: JournalEntry[],
  gap: number,
): VoiceIdentityCandidate | null {
  const pastWpm = wordsPerMinute(anchor);
  const currentWpm = wordsPerMinute(compare);
  if (pastWpm === null || currentWpm === null) return null;

  const median = medianWpm(sorted);
  if (!median) return null;

  const hadSlowPacing =
    pastWpm <= median * 0.78 ||
    (countMatches(anchor.transcript, LOOP_RE) >= 1 && hedgeCount(anchor) >= 2);
  const paceIncreased = currentWpm >= pastWpm * 1.2;
  if (!hadSlowPacing || !paceIncreased) return null;

  return {
    id: `voice-pause-${anchor.id}-${compare.id}`,
    kind: "pause_less",
    text: KIND_COPY.pause_less,
    anchorEntryId: anchor.id,
    strength: 76 + Math.min(currentWpm - pastWpm, 18) + Math.min(gap, 8),
    ...evidencePair(anchor, compare),
  };
}

function detectSelfLanguageShift(
  anchor: JournalEntry,
  compare: JournalEntry,
  gap: number,
): VoiceIdentityCandidate | null {
  const pastSelf = selfLanguageCount(anchor);
  const currentSelf = selfLanguageCount(compare);
  const shift = Math.abs(currentSelf - pastSelf);
  if (shift < 2 && pastSelf < 2 && currentSelf < 2) return null;

  const pastPhrase = anchor.transcript.match(SELF_RE)?.[0]?.toLowerCase();
  const currentPhrase = compare.transcript.match(SELF_RE)?.[0]?.toLowerCase();
  const wordingChanged = Boolean(pastPhrase && currentPhrase && pastPhrase !== currentPhrase);
  if (!wordingChanged && shift < 3) return null;

  return {
    id: `voice-self-${anchor.id}-${compare.id}`,
    kind: "self_language_shift",
    text: KIND_COPY.self_language_shift,
    anchorEntryId: anchor.id,
    strength: 73 + shift * 3 + (wordingChanged ? 4 : 0) + Math.min(gap, 8),
    ...evidencePair(anchor, compare),
  };
}

function collectForAnchor(
  sorted: JournalEntry[],
  anchor: JournalEntry,
  minStrength: number,
): VoiceIdentityCandidate[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const anchorIdx = sorted.findIndex((row) => row.id === anchor.id);
  if (anchorIdx < 0) return [];

  const prior = sorted.slice(0, anchorIdx);
  const later = sorted.slice(anchorIdx + 1);
  const notes: VoiceIdentityCandidate[] = [];

  const comparePool = [...prior.slice(-4), ...later.slice(0, 4)];
  for (const compare of comparePool) {
    if (compare.id === anchor.id) continue;

    const gap = daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(compare.createdAt));
    if (gap < MIN_GAP_DAYS) continue;

    const compareIsLater =
      new Date(compare.createdAt).getTime() > new Date(anchor.createdAt).getTime();
    const past = compareIsLater ? anchor : compare;
    const current = compareIsLater ? compare : anchor;
    if (past.id === current.id) continue;

    const overlap = sharedThemes(past, current);
    const detectors = [
      () => detectMoreCertain(past, current, gap),
      () => detectMoreDirect(past, current, gap),
      () => detectStoppedApologising(past, current, gap),
      () => detectSelfLanguageShift(past, current, gap),
    ];
    if (overlap.length > 0) {
      for (const detector of detectors) {
        const candidate = detector();
        if (candidate) pushCandidate(notes, candidate, minStrength);
      }
    }

    const pauseCandidate = detectPauseLess(past, current, sorted, gap);
    if (pauseCandidate && overlap.length > 0) {
      pushCandidate(notes, pauseCandidate, minStrength);
    }
  }

  return notes;
}

function toMemoryNote(candidate: VoiceIdentityCandidate): MemoryNote {
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

/** Internal ranking — voice identity candidates for an anchor entry. */
export function buildVoiceIdentityReport(
  entries: JournalEntry[],
  anchorEntryId?: string,
  minStrength = VOICE_ENTRY_MIN,
): VoiceIdentityReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { candidates: [], hasData: false };
  }

  const anchors = anchorEntryId
    ? sorted.filter((row) => row.id === anchorEntryId)
    : sorted.slice(0, -1);

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
  surface: VoiceIdentitySurface,
  minStrength: number,
): MemoryNote | null {
  touchSession();
  if (surface !== "entry" && !shouldAllowSurfaceShow()) return null;

  const report = buildVoiceIdentityReport(entries, anchorEntryId, minStrength);
  const best = report.candidates[0];
  if (!best || best.strength < minStrength) return null;
  if (isTextFatigued(best.text)) return null;

  recordShown(best, surface);
  return guardSurfacedNote(toMemoryNote(best), entries, "voice_identity");
}

/** Entry revisit — how you sound now vs before on this thread. */
export function pickVoiceIdentityForEntry(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote | null {
  const sorted = sortedEntries(entries);
  const idx = sorted.findIndex((row) => row.id === entryId);
  if (idx < 0 || idx >= sorted.length - 1) return null;
  return pickBest(entries, entryId, "entry", VOICE_ENTRY_MIN);
}

function pickSurfaceMoment(
  entries: JournalEntry[],
  surface: "timeline" | "monthly",
): MemoryNote | null {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) return null;

  const note = pickBest(entries, undefined, surface, VOICE_SURFACE_MIN);
  if (!note) return null;

  return calibratePrimaryNote([note], sorted, surface);
}

export function timelineVoiceIdentityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "timeline");
}

export function monthlyVoiceIdentityMoment(entries: JournalEntry[]): MemoryNote | null {
  return pickSurfaceMoment(entries, "monthly");
}

/** Debug — all voice identity candidates meeting entry threshold. */
export function voiceIdentityDebugCandidates(entries: JournalEntry[]): MemoryNote[] {
  return buildVoiceIdentityReport(entries, undefined, VOICE_ENTRY_MIN).candidates.map(toMemoryNote);
}

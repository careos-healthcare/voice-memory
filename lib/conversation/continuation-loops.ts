import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { trackLocalEvent, readLocalEvents } from "@/lib/local-analytics";
import { recordUnfinishedContinuation } from "@/lib/sync/cross-device-continuity";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { entrySnippet, hedgeCount } from "@/lib/memory/language-fingerprint";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export const CONTINUATION_COPY = {
  stoppedHere: "You stopped here.",
  moreToSay: "There may be more to say now.",
  neverFinished: "You never finished this thought.",
  cameBackNotFully: "You came back, but not fully.",
  sayBackToSelf: "What would you say back to this version of you?",
} as const;

export type ContinuationKind =
  | "stopped_here"
  | "unfinished_thought"
  | "ending_uncertainty"
  | "repeated_unresolved"
  | "revisit_contrast"
  | "revisit_no_reflection"
  | "partial_return";

export interface ContinuationCandidate {
  id: string;
  kind: ContinuationKind;
  text: string;
  strength: number;
  noteId: string;
  noteText: string;
  entryId?: string;
  pastEntryId?: string;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
}

const CONTINUATION_META_KEY = "voicememory_continuation_meta";

const UNRESOLVED_RE =
  /\b(not sure|don't know|unclear|unresolved|still thinking|figure out|work out|maybe|i guess)\b/i;
const TRAILING_OFF_RE = /\b(but|and|so|like|or|when|if)\s*\.?\s*$/i;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
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

/** Transcript ends mid-thought or leaves tension open. */
export function detectUnfinishedThought(entry: JournalEntry): ContinuationCandidate | null {
  const trimmed = entry.transcript.trim();
  if (trimmed.length < 24) return null;

  const lastSentence = trimmed.split(/[.!?]/).filter(Boolean).pop()?.trim() ?? trimmed;
  const endsOpen =
    !/[.!?]$/.test(trimmed) ||
    TRAILING_OFF_RE.test(trimmed) ||
    trimmed.endsWith("…") ||
    trimmed.endsWith("...");
  const hasTension = Boolean(entry.reflection.tensionOrContradiction?.trim());
  const hasAvoidance = Boolean(entry.reflection.avoidedOrVagueArea?.trim());

  if (!endsOpen && !hasTension && !hasAvoidance) return null;

  let strength = 62;
  if (endsOpen) strength += 4;
  if (hasTension) strength += 3;
  if (hasAvoidance) strength += 2;
  if (lastSentence.length >= 40) strength += 2;

  return {
    id: `continuation-unfinished-${entry.id}`,
    kind: "unfinished_thought",
    text: CONTINUATION_COPY.neverFinished,
    strength,
    noteId: entry.id,
    noteText: entrySnippet(entry),
    entryId: entry.id,
    currentQuote: entrySnippet(entry),
    currentDateLabel: formatRelativeDate(entry.createdAt),
  };
}

/** Last lines carry uncertainty or hedging. */
export function detectEndingUncertainty(entry: JournalEntry): ContinuationCandidate | null {
  const tail = entry.transcript.trim().slice(-100);
  if (tail.length < 16) return null;

  const uncertain =
    UNRESOLVED_RE.test(tail) ||
    hedgeCount({ ...entry, transcript: tail }) >= 2 ||
    Boolean(entry.reflection.avoidedOrVagueArea?.trim());

  if (!uncertain) return null;

  return {
    id: `continuation-uncertain-${entry.id}`,
    kind: "ending_uncertainty",
    text: CONTINUATION_COPY.moreToSay,
    strength: 64 + (UNRESOLVED_RE.test(tail) ? 4 : 0),
    noteId: entry.id,
    noteText: entrySnippet(entry),
    entryId: entry.id,
    currentQuote: entrySnippet(entry),
    currentDateLabel: formatRelativeDate(entry.createdAt),
  };
}

/** Same unresolved phrase keeps appearing. */
export function detectRepeatedUnresolvedLine(
  entries: JournalEntry[],
  anchor?: JournalEntry,
): ContinuationCandidate | null {
  const sorted = sortedEntries(entries);
  const target = anchor ?? sorted[sorted.length - 1];
  if (!target) return null;

  const phrases = buildPhraseMemory(sorted);
  for (const record of phrases) {
    if (record.count < 2) continue;
    if (!record.entryIds.includes(target.id)) continue;

    const hits = sorted.filter(
      (row) =>
        record.entryIds.includes(row.id) &&
        (Boolean(row.reflection.tensionOrContradiction?.trim()) ||
          Boolean(row.reflection.avoidedOrVagueArea?.trim()) ||
          UNRESOLVED_RE.test(row.transcript)),
    );
    if (hits.length < 2) continue;

    const prior = hits.find((row) => row.id !== target.id) ?? hits[0];
    const ev = evidencePair(prior, target);

    return {
      id: `continuation-repeat-${record.phrase.replace(/\s+/g, "-").slice(0, 12)}-${target.id}`,
      kind: "repeated_unresolved",
      text: CONTINUATION_COPY.neverFinished,
      strength: 66 + hits.length * 2,
      noteId: target.id,
      noteText: entrySnippet(target),
      ...ev,
    };
  }

  return null;
}

/** Revisit with quote-backed before/after contrast. */
export function detectRevisitContrast(notes: MemoryNote[]): ContinuationCandidate | null {
  for (const note of notes) {
    if (!note.pastQuote?.trim() || !note.currentQuote?.trim()) continue;
    if (note.confidence < 62) continue;

    return {
      id: `continuation-contrast-${note.id}`,
      kind: "revisit_contrast",
      text: CONTINUATION_COPY.sayBackToSelf,
      strength: Math.max(note.confidence, 70),
      noteId: note.id,
      noteText: note.text,
      entryId: note.entryId,
      pastEntryId: note.pastEntryId,
      pastQuote: note.pastQuote,
      currentQuote: note.currentQuote,
      pastDateLabel: note.pastDateLabel,
      currentDateLabel: note.currentDateLabel,
    };
  }

  return null;
}

/** Old entry reopened — no new reflection on the thread since. */
export function detectRevisitNoNewReflection(
  entries: JournalEntry[],
  entryId: string,
): ContinuationCandidate | null {
  const sorted = sortedEntries(entries);
  const entry = sorted.find((row) => row.id === entryId);
  if (!entry) return null;

  const summary = entryInteractionSummary(entryId);
  if (!summary || summary.viewCount < 2) return null;

  const lastViewed = new Date(summary.lastViewedAt).getTime();
  const laterOnThread = sorted.filter((row) => {
    if (new Date(row.createdAt).getTime() <= lastViewed) return false;
    return sharedThemes(entry, row).length > 0;
  });

  if (laterOnThread.length > 0) return null;

  const gap = daysBetweenKeys(toDayKey(entry.createdAt), toDayKey(summary.lastViewedAt));
  if (gap < 5) return null;

  return {
    id: `continuation-reopen-${entryId}`,
    kind: "revisit_no_reflection",
    text: CONTINUATION_COPY.cameBackNotFully,
    strength: 68 + Math.min(gap, 14),
    noteId: entryId,
    noteText: entrySnippet(entry),
    entryId,
    currentQuote: entrySnippet(entry),
    currentDateLabel: formatRelativeDate(entry.createdAt),
  };
}

/** Returned to a topic without recording a follow-up. */
export function detectPartialReturn(
  entries: JournalEntry[],
  entryId?: string,
): ContinuationCandidate | null {
  const events = readRetentionLoopEvents();
  const revisits = events
    .filter((row) => row.kind === "entry_revisited")
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());

  const targetRevisit = entryId
    ? revisits.find((row) => row.entryId === entryId)
    : revisits[0];
  if (!targetRevisit?.entryId) return null;

  const completed = events.some(
    (row) =>
      row.kind === "followup_recording_completed" &&
      (row.noteId === targetRevisit.noteId ||
        row.noteId === targetRevisit.entryId ||
        row.entryId === targetRevisit.entryId),
  );
  if (completed) return null;

  const sorted = sortedEntries(entries);
  const entry = sorted.find((row) => row.id === targetRevisit.entryId);
  if (!entry) return null;

  const gap = daysBetweenKeys(toDayKey(targetRevisit.at), toDayKey(new Date().toISOString()));
  if (gap > 21) return null;

  return {
    id: `continuation-partial-${targetRevisit.entryId}`,
    kind: "partial_return",
    text: CONTINUATION_COPY.cameBackNotFully,
    strength: 67 + Math.min(gap, 10),
    noteId: targetRevisit.entryId,
    noteText: entrySnippet(entry),
    entryId: targetRevisit.entryId,
    currentQuote: entrySnippet(entry),
    currentDateLabel: formatRelativeDate(entry.createdAt),
  };
}

/** Latest entry stopped mid-thread after a short gap. */
export function detectStoppedHere(
  entries: JournalEntry[],
): ContinuationCandidate | null {
  const sorted = sortedEntries(entries);
  if (sorted.length < 2) return null;

  const latest = sorted[sorted.length - 1];
  const prior = sorted[sorted.length - 2];
  const gap = daysBetweenKeys(toDayKey(prior.createdAt), toDayKey(latest.createdAt));
  if (gap > 4) return null;

  const overlap = sharedThemes(latest, prior);
  if (overlap.length === 0) return null;

  const open =
    detectUnfinishedThought(latest) !== null ||
    detectEndingUncertainty(latest) !== null ||
    Boolean(latest.reflection.tensionOrContradiction?.trim());

  if (!open) return null;

  const ev = evidencePair(prior, latest);

  return {
    id: `continuation-stopped-${latest.id}`,
    kind: "stopped_here",
    text: CONTINUATION_COPY.stoppedHere,
    strength: 65 + overlap.length * 2,
    noteId: latest.id,
    noteText: entrySnippet(latest),
    ...ev,
  };
}

/** Rank continuation candidates from entries and visible notes. */
export function gatherContinuationCandidates(
  entries: JournalEntry[],
  notes: MemoryNote[] = [],
  entryId?: string,
): ContinuationCandidate[] {
  const sorted = sortedEntries(entries);
  if (sorted.length === 0) return [];

  const anchor = entryId
    ? sorted.find((row) => row.id === entryId)
    : sorted[sorted.length - 1];
  if (!anchor) return [];

  const candidates: ContinuationCandidate[] = [];

  const contrast = detectRevisitContrast(notes);
  if (contrast) candidates.push(contrast);

  if (entryId) {
    const reopen = detectRevisitNoNewReflection(sorted, entryId);
    if (reopen) candidates.push(reopen);
  }

  const partial = detectPartialReturn(sorted, entryId ?? anchor.id);
  if (partial) candidates.push(partial);

  const stopped = detectStoppedHere(sorted);
  if (stopped) candidates.push(stopped);

  const repeated = detectRepeatedUnresolvedLine(sorted, anchor);
  if (repeated) candidates.push(repeated);

  const unfinished = detectUnfinishedThought(anchor);
  if (unfinished) candidates.push(unfinished);

  const uncertain = detectEndingUncertainty(anchor);
  if (uncertain) candidates.push(uncertain);

  return candidates
    .sort((a, b) => b.strength - a.strength)
    .filter((item, index, list) => {
      const key = `${item.kind}:${item.text}`;
      return list.findIndex((row) => `${row.kind}:${row.text}` === key) === index;
    });
}

export function storeContinuationMeta(promptId: string, noteId: string): void {
  if (typeof window === "undefined") return;
  sessionStorage.setItem(
    CONTINUATION_META_KEY,
    JSON.stringify({ promptId, noteId }),
  );
  recordUnfinishedContinuation({ promptId, noteId });
}

export function peekContinuationMeta(): { promptId: string; noteId: string } | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = sessionStorage.getItem(CONTINUATION_META_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as { promptId: string; noteId: string };
  } catch {
    return null;
  }
}

export function consumeContinuationMeta(): { promptId: string; noteId: string } | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = sessionStorage.getItem(CONTINUATION_META_KEY);
    sessionStorage.removeItem(CONTINUATION_META_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as { promptId: string; noteId: string };
  } catch {
    return null;
  }
}

export function trackContinuationSeen(promptId: string, noteId?: string): void {
  trackLocalEvent("continuation_seen", {
    promptId,
    ...(noteId ? { noteId } : {}),
  });
}

export function trackContinuationStarted(promptId: string, noteId?: string): void {
  trackLocalEvent("continuation_started", {
    promptId,
    ...(noteId ? { noteId } : {}),
  });
}

export function trackContinuationCompleted(promptId: string, entryId: string, noteId?: string): void {
  trackLocalEvent("continuation_completed", {
    promptId,
    entryId,
    ...(noteId ? { noteId } : {}),
  });
}

/** Whether a continuation loop recently completed for this note. */
export function hasRecentContinuationCompleted(noteId: string): boolean {
  const cutoff = Date.now() - 1000 * 60 * 60 * 24 * 14;
  return readLocalEvents().some(
    (event) =>
      event.name === "continuation_completed" &&
      event.meta?.noteId === noteId &&
      new Date(event.at).getTime() >= cutoff,
  );
}

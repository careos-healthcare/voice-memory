import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { CONTINUATION_COPY } from "@/lib/conversation/continuation-copy";
import {
  detectEndingUncertainty,
  detectPartialReturn,
  detectRepeatedUnresolvedLine,
  detectRevisitNoNewReflection,
  detectUnfinishedThought,
} from "@/lib/conversation/continuation-loops";
import { buildRecorderContinuationPrompt } from "@/lib/conversation/followup-prompts";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { applyMemoryHierarchy, pickStrongestMemoryNote } from "@/lib/refinement/memory-hierarchy";
import { formatRelativeDate } from "@/lib/utils";
import type {
  ConversationContinuityContext,
  ConversationContinuityKind,
  ConversationContinuityNote,
  ConversationContinuityReport,
} from "@/types/conversation-continuity";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const CONTINUITY_KEY = "voicememory_conversation_continuity";
const MIN_ENTRIES = 3;
const STRONG_MIN = 62;
const RECORDER_STRONG_MIN = 66;
const MIN_SESSIONS = 2;
const MIN_DAYS = 5;
const TEXT_COOLDOWN_DAYS = 21;
const RETURN_GAP_DAYS = 5;
const FOLLOWUP_GAP_DAYS = 3;
const STOP_GAP_DAYS = 5;

const LOOP_RE =
  /\b(same loop|keep coming back|again before|that loop|same pattern|i keep|came back briefly)\b/i;
const UNRESOLVED_RE =
  /\b(not sure|don't know|unclear|unresolved|still thinking|figure out|work out|need to|have to)\b/i;
const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely)\b/gi;

export interface ConversationContinuityOptions {
  context: ConversationContinuityContext;
  entryId?: string;
  record?: boolean;
}

interface ContinuityState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: ConversationContinuityContext;
    shownAt: number;
  }>;
}

const CONTEXT_KIND_PRIORITY: Record<
  ConversationContinuityContext,
  ConversationContinuityKind[]
> = {
  homepage: [
    "came_back",
    "sounds_like_continuation",
    "left_unresolved",
    "returned_differently",
  ],
  entry: [
    "sounds_like_continuation",
    "came_back",
    "left_unresolved",
    "stopped_here",
    "returned_differently",
    "thread_changed",
  ],
  recorder: [
    "stopped_here",
    "unfinished_thought",
    "ending_uncertainty",
    "sounds_like_continuation",
    "partial_return",
    "revisit_no_reflection",
    "left_unresolved",
    "came_back",
  ],
};

const COPY: Record<ConversationContinuityKind, string> = {
  came_back: CONTINUATION_COPY.cameBackNotFully,
  left_unresolved: CONTINUATION_COPY.neverFinished,
  sounds_like_continuation: CONTINUATION_COPY.stoppedHere,
  stopped_here: CONTINUATION_COPY.stoppedHere,
  returned_differently: CONTINUATION_COPY.sayBackToSelf,
  thread_changed: CONTINUATION_COPY.moreToSay,
  unfinished_thought: CONTINUATION_COPY.neverFinished,
  ending_uncertainty: CONTINUATION_COPY.moreToSay,
  repeated_unresolved: CONTINUATION_COPY.neverFinished,
  revisit_no_reflection: CONTINUATION_COPY.cameBackNotFully,
  partial_return: CONTINUATION_COPY.cameBackNotFully,
};

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

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

function readState(): ContinuityState {
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
    const raw = localStorage.getItem(CONTINUITY_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    const parsed = JSON.parse(raw) as ContinuityState;
    return {
      sessionCount: parsed.sessionCount ?? 0,
      lastSessionDay: parsed.lastSessionDay ?? "",
      sessionsAtLastShow: parsed.sessionsAtLastShow ?? 0,
      lastShownAt: parsed.lastShownAt ?? 0,
      records: Array.isArray(parsed.records) ? parsed.records : [],
    };
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

function writeState(state: ContinuityState): void {
  if (!isBrowser()) return;
  localStorage.setItem(CONTINUITY_KEY, JSON.stringify(state));
}

export function bumpConversationSession(): ContinuityState {
  const today = toDayKey(new Date().toISOString());
  const state = readState();
  if (state.lastSessionDay !== today) {
    state.sessionCount += 1;
    state.lastSessionDay = today;
    writeState(state);
  }
  return state;
}

export function clearConversationContinuityMemory(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(CONTINUITY_KEY);
}

function daysSince(timestamp: number): number {
  if (!timestamp) return Number.POSITIVE_INFINITY;
  return (Date.now() - timestamp) / (1000 * 60 * 60 * 24);
}

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  return readState().records.some(
    (record) => record.textKey === key && daysSince(record.shownAt) < TEXT_COOLDOWN_DAYS,
  );
}

function canShowContinuity(state: ContinuityState): boolean {
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS) return false;
  if (daysSince(state.lastShownAt) < MIN_DAYS) return false;
  return true;
}

function recordContinuityShown(
  note: ConversationContinuityNote,
  context: ConversationContinuityContext,
): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      noteId: note.id,
      textKey: textKey(note.text),
      surface: context,
      shownAt: now,
    },
  ].slice(-24);
  writeState(state);
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
    ConversationContinuityNote,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasSingleAnchor = Boolean(item.currentQuote?.trim() && item.currentDateLabel);
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates || hasSingleAnchor;
}

function pushCandidate(
  bucket: ConversationContinuityNote[],
  item: Omit<ConversationContinuityNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < STRONG_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  if (isTextFatigued(item.text)) return;
  bucket.push({ ...item, strength });
}

function themeHits(allSorted: JournalEntry[], themeKey: string): JournalEntry[] {
  return allSorted.filter((entry) => hasTheme(entry, themeKey));
}

function detectCameBack(
  anchor: JournalEntry,
  prior: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < RETURN_GAP_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    pushCandidate(notes, {
      id: `continuity-came-back-${old.id}-${anchor.id}`,
      kind: "came_back",
      text: COPY.came_back,
      strength: 62 + Math.min(gap, 14) + overlap.length * 2,
      ...evidencePair(old, anchor),
    });
    break;
  }

  return notes;
}

function detectLeftUnresolved(
  anchor: JournalEntry,
  prior: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < 3) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    const oldText = `${old.transcript} ${old.reflection.tensionOrContradiction ?? ""} ${old.reflection.avoidedOrVagueArea ?? ""}`;
    const unresolved =
      Boolean(old.reflection.tensionOrContradiction?.trim()) ||
      Boolean(old.reflection.avoidedOrVagueArea?.trim()) ||
      UNRESOLVED_RE.test(oldText) ||
      old.reflection.emotionalIntensity >= 7;
    if (!unresolved) continue;

    pushCandidate(notes, {
      id: `continuity-unresolved-${old.id}-${anchor.id}`,
      kind: "left_unresolved",
      text: COPY.left_unresolved,
      strength: 64 + overlap.length * 2 + (old.reflection.emotionalIntensity >= 7 ? 2 : 0),
      ...evidencePair(old, anchor),
    });
    break;
  }

  return notes;
}

function detectSoundsLikeContinuation(
  anchor: JournalEntry,
  prior: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];
  if (prior.length === 0) return notes;

  const latest = prior[prior.length - 1];
  const gap = daysBetweenKeys(toDayKey(latest.createdAt), toDayKey(anchor.createdAt));
  if (gap > FOLLOWUP_GAP_DAYS) return notes;

  const overlap = sharedThemes(anchor, latest);
  if (overlap.length === 0) return notes;

  const intensityDiff = Math.abs(
    anchor.reflection.emotionalIntensity - latest.reflection.emotionalIntensity,
  );
  if (intensityDiff > 3 && gap > 1) return notes;

  pushCandidate(notes, {
    id: `continuity-followup-${latest.id}-${anchor.id}`,
    kind: "sounds_like_continuation",
    text: COPY.sounds_like_continuation,
    strength: 65 + overlap.length * 2 + (gap <= 1 ? 3 : 0),
    ...evidencePair(latest, anchor),
  });

  return notes;
}

function detectStoppedHere(
  anchor: JournalEntry,
  prior: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < STOP_GAP_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    const hadLoop = LOOP_RE.test(old.transcript);
    if (!hadLoop) continue;

    const resumedLoop = LOOP_RE.test(anchor.transcript);
    if (resumedLoop) continue;

    pushCandidate(notes, {
      id: `continuity-stopped-${old.id}-${anchor.id}`,
      kind: "stopped_here",
      text: COPY.stopped_here,
      strength: 63 + Math.min(gap, 12),
      ...evidencePair(old, anchor),
    });
    break;
  }

  return notes;
}

function detectReturnedDifferently(
  anchor: JournalEntry,
  prior: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];
  const anchorDay = toDayKey(anchor.createdAt);

  for (let i = prior.length - 1; i >= 0; i -= 1) {
    const old = prior[i];
    const gap = daysBetweenKeys(toDayKey(old.createdAt), anchorDay);
    if (gap < RETURN_GAP_DAYS) continue;

    const overlap = sharedThemes(anchor, old);
    if (overlap.length === 0) continue;

    const intensityShift = Math.abs(
      anchor.reflection.emotionalIntensity - old.reflection.emotionalIntensity,
    );
    const hedgeShift =
      countMatches(anchor.transcript, HEDGE_RE) - countMatches(old.transcript, HEDGE_RE);
    const directShift =
      countMatches(anchor.transcript, DIRECT_RE) - countMatches(old.transcript, DIRECT_RE);

    const changed =
      intensityShift >= 2 || hedgeShift <= -2 || directShift >= 2;
    if (!changed) continue;

    pushCandidate(notes, {
      id: `continuity-different-${old.id}-${anchor.id}`,
      kind: "returned_differently",
      text: COPY.returned_differently,
      strength: 64 + intensityShift + Math.max(0, directShift),
      ...evidencePair(old, anchor),
    });
    break;
  }

  return notes;
}

function detectThreadChanged(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = themeHits(allSorted, themeKey);
    if (hits.length < 3) continue;
    if (hits[hits.length - 1].id !== anchor.id) continue;

    const early = hits.slice(0, Math.floor(hits.length / 2));
    const late = hits.slice(Math.floor(hits.length / 2));
    const earlyAvg = roundAvg(early.map((e) => e.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((e) => e.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((e) => countMatches(e.transcript, HEDGE_RE)));
    const lateDirect = roundAvg(late.map((e) => countMatches(e.transcript, DIRECT_RE)));
    const earlyDirect = roundAvg(early.map((e) => countMatches(e.transcript, DIRECT_RE)));

    const evolved =
      lateAvg <= earlyAvg - 1 ||
      lateHedge <= earlyHedge - 0.8 ||
      lateDirect >= earlyDirect + 0.8;
    if (!evolved) continue;

    pushCandidate(notes, {
      id: `continuity-thread-${themeKey}-${anchor.id}`,
      kind: "thread_changed",
      text: COPY.thread_changed,
      strength: 65 + hits.length,
      ...evidencePair(early[early.length - 1], anchor),
    });
    break;
  }

  return notes;
}

function detectRecurringUnresolved(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const notes: ConversationContinuityNote[] = [];

  for (const theme of anchor.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = themeHits(allSorted, themeKey);
    if (hits.length < 3) continue;
    if (hits[hits.length - 1].id !== anchor.id) continue;

    const unresolvedHits = hits.filter(
      (entry) =>
        Boolean(entry.reflection.tensionOrContradiction?.trim()) ||
        Boolean(entry.reflection.avoidedOrVagueArea?.trim()) ||
        UNRESOLVED_RE.test(entry.transcript),
    );
    if (unresolvedHits.length < 2) continue;

    const prior = hits[hits.length - 2];
    pushCandidate(notes, {
      id: `continuity-recurring-${themeKey}-${anchor.id}`,
      kind: "left_unresolved",
      text: COPY.left_unresolved,
      strength: 63 + unresolvedHits.length,
      ...evidencePair(prior, anchor),
    });
    break;
  }

  return notes;
}

function continuationToContinuityNote(
  candidate: NonNullable<ReturnType<typeof detectUnfinishedThought>>,
  kind: ConversationContinuityKind,
): ConversationContinuityNote {
  return {
    id: candidate.id.replace("continuation-", "continuity-"),
    kind,
    text: candidate.text,
    strength: candidate.strength,
    pastQuote: candidate.pastQuote,
    currentQuote: candidate.currentQuote,
    pastDateLabel: candidate.pastDateLabel,
    currentDateLabel: candidate.currentDateLabel,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId,
  };
}

function detectUnfinishedThoughtNote(
  anchor: JournalEntry,
): ConversationContinuityNote[] {
  const candidate = detectUnfinishedThought(anchor);
  if (!candidate) return [];
  const notes: ConversationContinuityNote[] = [];
  pushCandidate(notes, continuationToContinuityNote(candidate, "unfinished_thought"));
  return notes;
}

function detectEndingUncertaintyNote(
  anchor: JournalEntry,
): ConversationContinuityNote[] {
  const candidate = detectEndingUncertainty(anchor);
  if (!candidate) return [];
  const notes: ConversationContinuityNote[] = [];
  pushCandidate(notes, continuationToContinuityNote(candidate, "ending_uncertainty"));
  return notes;
}

function detectRepeatedUnresolvedNote(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const candidate = detectRepeatedUnresolvedLine(allSorted, anchor);
  if (!candidate) return [];
  const notes: ConversationContinuityNote[] = [];
  pushCandidate(notes, continuationToContinuityNote(candidate, "repeated_unresolved"));
  return notes;
}

function detectRevisitNoReflectionNote(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const candidate = detectRevisitNoNewReflection(allSorted, anchor.id);
  if (!candidate) return [];
  const notes: ConversationContinuityNote[] = [];
  pushCandidate(notes, continuationToContinuityNote(candidate, "revisit_no_reflection"));
  return notes;
}

function detectPartialReturnNote(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const candidate = detectPartialReturn(allSorted, anchor.id);
  if (!candidate) return [];
  const notes: ConversationContinuityNote[] = [];
  pushCandidate(notes, continuationToContinuityNote(candidate, "partial_return"));
  return notes;
}

function detectForAnchor(
  anchor: JournalEntry,
  allSorted: JournalEntry[],
): ConversationContinuityNote[] {
  const idx = allSorted.findIndex((e) => e.id === anchor.id);
  const prior = idx > 0 ? allSorted.slice(0, idx) : [];

  return [
    ...detectUnfinishedThoughtNote(anchor),
    ...detectEndingUncertaintyNote(anchor),
    ...detectRepeatedUnresolvedNote(anchor, allSorted),
    ...detectRevisitNoReflectionNote(anchor, allSorted),
    ...detectPartialReturnNote(anchor, allSorted),
    ...detectSoundsLikeContinuation(anchor, prior),
    ...detectCameBack(anchor, prior),
    ...detectLeftUnresolved(anchor, prior),
    ...detectStoppedHere(anchor, prior),
    ...detectReturnedDifferently(anchor, prior),
    ...detectThreadChanged(anchor, allSorted),
    ...detectRecurringUnresolved(anchor, allSorted),
  ];
}

function dedupeNotes(notes: ConversationContinuityNote[]): ConversationContinuityNote[] {
  const seen = new Set<string>();
  return notes
    .filter((note) => note.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((note) => {
      const key = `${note.kind}:${note.text}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  candidates: ConversationContinuityNote[],
  context: ConversationContinuityContext,
  minStrength: number,
): ConversationContinuityNote[] {
  const sorted = dedupeNotes(candidates).filter((note) => note.strength >= minStrength);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: ConversationContinuityNote[] = [];
  const usedKinds = new Set<ConversationContinuityKind>();

  for (const kind of priority) {
    const match = sorted.find((note) => note.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
      break;
    }
  }

  if (picked.length === 0 && sorted.length > 0) {
    picked.push(sorted[0]);
  }

  return picked.slice(0, 1);
}

function resolveAnchor(
  allSorted: JournalEntry[],
  entryId?: string,
): JournalEntry | null {
  if (entryId) {
    return allSorted.find((e) => e.id === entryId) ?? null;
  }
  return allSorted.length > 0 ? allSorted[allSorted.length - 1] : null;
}

/** Detect sparse conversational continuity — ongoing remembered conversation. */
export function buildConversationContinuityReport(
  entries: JournalEntry[],
  options: ConversationContinuityOptions,
): ConversationContinuityReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const anchor = resolveAnchor(sorted, options.entryId);
  if (!anchor) {
    return { notes: [], hasData: false };
  }

  const state = bumpConversationSession();
  if (!canShowContinuity(state)) {
    return { notes: [], hasData: false };
  }

  const minStrength = options.context === "recorder" ? RECORDER_STRONG_MIN : STRONG_MIN;
  const candidates = detectForAnchor(anchor, sorted);
  const notes = pickForContext(candidates, options.context, minStrength);

  if (notes.length > 0 && options.record !== false) {
    recordContinuityShown(notes[0], options.context);
  }

  return { notes, hasData: notes.length > 0 };
}

function categoryForKind(kind: ConversationContinuityKind): MemoryNote["category"] {
  switch (kind) {
    case "returned_differently":
    case "thread_changed":
      return "changed";
    case "left_unresolved":
    case "unfinished_thought":
    case "ending_uncertainty":
    case "repeated_unresolved":
      return "faded";
    default:
      return "returned";
  }
}

export function conversationContinuityToNotes(
  notes: ConversationContinuityNote[],
): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: categoryForKind(note.kind),
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
  }));
}

export function homepageContinuationNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  return applyMemoryHierarchy(
    conversationContinuityToNotes(
      buildConversationContinuityReport(entries, { context: "homepage" }).notes,
    ),
    entries,
    limit,
  );
}

export function entryContinuationOpener(
  entries: JournalEntry[],
  entryId: string,
): MemoryNote | null {
  return pickStrongestMemoryNote(
    conversationContinuityToNotes(
      buildConversationContinuityReport(entries, {
        context: "entry",
        entryId,
      }).notes,
    ),
    entries,
  );
}

/** Optional quiet line before recording — unfinished conversation, not coaching. */
export function recorderPreRecordLine(entries: JournalEntry[]): string | null {
  const prompt = buildRecorderContinuationPrompt(entries);
  return prompt?.text ?? null;
}

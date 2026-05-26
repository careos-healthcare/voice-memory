import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { linkedEntriesForNote } from "@/lib/refinement/note-linked-entries";
import { trackLocalEvent } from "@/lib/local-analytics";
import { assessResurfacingWhyNow } from "@/lib/revisit/resurfacing-why-now";
import { collectResurfacingConfidenceCandidates } from "@/lib/revisit/resurfacing-confidence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  CallbackLearningEventName,
  CallbackLearningEventRow,
  CallbackLearningKind,
  CallbackLearningWeights,
  CallbackLearningVerdict,
} from "@/types/callback-learning";

export const CALLBACK_LEARNING_EVENTS = {
  shown: "callback_shown",
  ignored: "callback_ignored",
  opened: "callback_opened",
  reread: "callback_reread",
  saved: "callback_saved",
  shared: "callback_shared",
  dismissed: "callback_dismissed",
  reflectionAfter: "reflection_after_callback",
  returnAfter: "return_after_callback",
} as const satisfies Record<string, CallbackLearningEventName>;

export const LEARNING_WEIGHT_MIN = -18;
export const LEARNING_WEIGHT_MAX = 18;
export const LEARNING_RANK_CAP = 12;
export const LEARNING_INTERACTION_CAP = 15;

const STORE_KEY = "voicememory_callback_learning";

const POSITIVE_EVENTS = new Set<CallbackLearningEventName>([
  CALLBACK_LEARNING_EVENTS.opened,
  CALLBACK_LEARNING_EVENTS.reread,
  CALLBACK_LEARNING_EVENTS.saved,
  CALLBACK_LEARNING_EVENTS.shared,
  CALLBACK_LEARNING_EVENTS.reflectionAfter,
  CALLBACK_LEARNING_EVENTS.returnAfter,
]);

const NEGATIVE_EVENTS = new Set<CallbackLearningEventName>([
  CALLBACK_LEARNING_EVENTS.ignored,
  CALLBACK_LEARNING_EVENTS.dismissed,
]);

const EVENT_DELTA: Record<CallbackLearningEventName, number> = {
  callback_shown: 0,
  callback_ignored: 3,
  callback_opened: 2,
  callback_reread: 1,
  callback_saved: 3,
  callback_shared: 3,
  callback_dismissed: 4,
  reflection_after_callback: 4,
  return_after_callback: 3,
};

interface LearningStore {
  weights: CallbackLearningWeights;
  events: CallbackLearningEventRow[];
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function defaultWeights(): CallbackLearningWeights {
  return {
    repeated_phrase: 0,
    repeated_concern: 0,
    mood_shift: 0,
    named_person_topic: 0,
    time_gap: 0,
    audio_photo_anchored: 0,
  };
}

function clampWeight(value: number): number {
  return Math.max(LEARNING_WEIGHT_MIN, Math.min(LEARNING_WEIGHT_MAX, Math.round(value)));
}

function readStore(): LearningStore {
  if (!isBrowser()) return { weights: defaultWeights(), events: [] };
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return { weights: defaultWeights(), events: [] };
    const parsed = JSON.parse(raw) as Partial<LearningStore>;
    return {
      weights: { ...defaultWeights(), ...(parsed.weights ?? {}) },
      events: Array.isArray(parsed.events) ? parsed.events.slice(-240) : [],
    };
  } catch {
    return { weights: defaultWeights(), events: [] };
  }
}

function writeStore(store: LearningStore): void {
  if (!isBrowser()) return;
  localStorage.setItem(
    STORE_KEY,
    JSON.stringify({
      weights: store.weights,
      events: store.events.slice(-240),
    }),
  );
}

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function kindsFromNoteId(noteId: string): CallbackLearningKind[] {
  const id = noteId.toLowerCase();
  const kinds = new Set<CallbackLearningKind>();

  if (/phrase|knows-me-phrase/.test(id)) kinds.add("repeated_phrase");
  if (/concern|loop|topic|entity|resurface/.test(id)) {
    kinds.add("repeated_concern");
    if (/person|entity/.test(id)) kinds.add("named_person_topic");
  }
  if (/calmer|heavier|tvn|then-vs|mood|different/.test(id)) kinds.add("mood_shift");
  if (/time-|same-day|same-week|dow|tod/.test(id)) kinds.add("time_gap");
  if (/audio|photo|voice/.test(id)) kinds.add("audio_photo_anchored");

  if (kinds.size === 0) kinds.add("repeated_concern");
  return [...kinds];
}

/** Classify which callback preference buckets a note belongs to. */
export function classifyCallbackLearningKinds(
  note: MemoryNote,
  entries: JournalEntry[],
): CallbackLearningKind[] {
  const kinds = new Set<CallbackLearningKind>(kindsFromNoteId(note.id));
  const gapDays = gapDaysForNote(note, entries);
  if (gapDays >= 3) kinds.add("time_gap");

  const whyNow = assessResurfacingWhyNow(note, entries);
  if (whyNow.primaryKind === "repeated_phrase_after_gap") kinds.add("repeated_phrase");
  if (whyNow.primaryKind === "repeated_concern_after_gap") kinds.add("repeated_concern");
  if (whyNow.primaryKind === "mood_shift_same_topic") kinds.add("mood_shift");
  if (whyNow.primaryKind === "named_person_topic_return") kinds.add("named_person_topic");
  if (
    whyNow.primaryKind === "same_weekday" ||
    whyNow.primaryKind === "same_time_of_day" ||
    whyNow.primaryKind === "quiet_gap_return"
  ) {
    kinds.add("time_gap");
  }

  for (const entry of linkedEntriesForNote(note, entries)) {
    if (entry.audioId?.trim() || entry.photo) {
      kinds.add("audio_photo_anchored");
    }
  }

  if (note.pastQuote?.trim() && note.currentQuote?.trim()) {
    kinds.add("repeated_phrase");
  }

  return kinds.size > 0 ? [...kinds] : ["repeated_concern"];
}

function resolveNote(
  note: MemoryNote | { id: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
): { note: MemoryNote; entries: JournalEntry[] } {
  const pool = entries ?? getMemoryEligibleEntries();
  const candidate =
    "text" in note && note.text
      ? (note as MemoryNote)
      : collectResurfacingConfidenceCandidates(pool).find((row) => row.id === note.id) ??
        ({
          id: note.id,
          text: "",
          entryId: note.entryId,
          pastEntryId: note.pastEntryId,
          category: "returned" as const,
          confidence: 0,
        } satisfies MemoryNote);

  return { note: candidate, entries: pool };
}

function applyEventToWeights(
  weights: CallbackLearningWeights,
  kinds: CallbackLearningKind[],
  event: CallbackLearningEventName,
): CallbackLearningWeights {
  if (kinds.length === 0 || EVENT_DELTA[event] === 0) return weights;
  const next = { ...weights };
  const delta = EVENT_DELTA[event];

  for (const kind of kinds) {
    if (POSITIVE_EVENTS.has(event)) {
      next[kind] = clampWeight(next[kind] + delta);
    } else if (NEGATIVE_EVENTS.has(event)) {
      next[kind] = clampWeight(next[kind] - delta);
    }
  }

  return next;
}

function recordLearningEvent(
  event: CallbackLearningEventName,
  noteRef: MemoryNote | { id: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  meta?: Record<string, string>,
): void {
  const { note, entries: resolvedEntries } = resolveNote(noteRef, entries);
  const kinds = classifyCallbackLearningKinds(note, resolvedEntries);
  const store = readStore();

  store.weights = applyEventToWeights(store.weights, kinds, event);
  store.events.push({
    event,
    at: new Date().toISOString(),
    noteId: note.id,
    kinds,
  });

  writeStore(store);
  trackLocalEvent(event, {
    noteId: note.id,
    entryId: note.entryId ?? "",
    kinds: kinds.join(","),
    ...meta,
  });
}

export function readCallbackLearningWeights(): CallbackLearningWeights {
  return readStore().weights;
}

export function readCallbackLearningEvents(limit = 40): CallbackLearningEventRow[] {
  return readStore().events.slice(-limit).reverse();
}

export function observeCallbackShown(
  noteRef: MemoryNote | { id: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  meta?: Record<string, string>,
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.shown, noteRef, entries, meta);
}

export function observeCallbackIgnored(
  noteRef: MemoryNote | { id: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.ignored, noteRef, entries);
}

export function observeCallbackOpened(
  noteRef: MemoryNote | { id: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  meta?: Record<string, string>,
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.opened, noteRef, entries, meta);
}

export function observeCallbackReread(
  noteRef: MemoryNote | { id: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.reread, noteRef, entries);
}

export function observeCallbackSaved(
  noteRef: MemoryNote | { id: string; entryId?: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.saved, noteRef, entries);
}

export function observeCallbackShared(
  noteRef: MemoryNote | { id: string; entryId?: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.shared, noteRef, entries);
}

export function observeCallbackDismissed(
  noteRef: MemoryNote | { id: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.dismissed, noteRef, entries);
}

export function observeReflectionAfterCallback(
  noteRef: MemoryNote | { id: string; entryId?: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.reflectionAfter, noteRef, entries);
}

export function observeReturnAfterCallback(
  noteRef: MemoryNote | { id: string; entryId?: string },
  entries?: JournalEntry[],
): void {
  recordLearningEvent(CALLBACK_LEARNING_EVENTS.returnAfter, noteRef, entries);
}

function averageWeightForKinds(
  weights: CallbackLearningWeights,
  kinds: CallbackLearningKind[],
): number {
  if (kinds.length === 0) return 0;
  const total = kinds.reduce((sum, kind) => sum + weights[kind], 0);
  return total / kinds.length;
}

/** Internal rank adjustment from learned callback preferences. */
export function getCallbackLearningRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
): number {
  return assessCallbackLearning(note, entries).rankAdjustment;
}

/** Internal interaction score boost from learned callback preferences. */
export function getCallbackLearningInteractionBoost(
  note: MemoryNote,
  entries: JournalEntry[],
): number {
  return assessCallbackLearning(note, entries).interactionBoost;
}

export function applyCallbackLearningRankAdjustment(
  note: MemoryNote,
  entries: JournalEntry[],
  baseScore: number,
): number {
  return baseScore + getCallbackLearningRankAdjustment(note, entries);
}

export function assessCallbackLearning(
  note: MemoryNote,
  entries: JournalEntry[],
): CallbackLearningVerdict {
  const kinds = classifyCallbackLearningKinds(note, entries);
  const weights = readCallbackLearningWeights();
  const average = averageWeightForKinds(weights, kinds);
  const rankAdjustment = Math.max(
    -LEARNING_RANK_CAP,
    Math.min(LEARNING_RANK_CAP, Math.round(average * 0.65)),
  );
  const interactionBoost = Math.max(
    -LEARNING_INTERACTION_CAP,
    Math.min(LEARNING_INTERACTION_CAP, Math.round(average * 0.75)),
  );

  return {
    noteId: note.id,
    kinds,
    weights,
    rankAdjustment,
    interactionBoost,
  };
}

export function collectCallbackLearningCandidates(entries: JournalEntry[]): MemoryNote[] {
  return collectResurfacingConfidenceCandidates(entries);
}

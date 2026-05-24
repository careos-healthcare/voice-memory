import { addDaysToKey, daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readLocalEvents } from "@/lib/local-analytics";
import { getAllEntries } from "@/lib/storage";

export type RetentionLoopEventKind =
  | "entry_revisited"
  | "resurfaced_memory_clicked"
  | "old_entry_opened_from_note"
  | "bookmark_created"
  | "followup_recording_started"
  | "followup_recording_completed"
  | "copied_memory_moment"
  | "returned_next_day"
  | "returned_within_7_days";

export interface RetentionLoopEvent {
  id: string;
  kind: RetentionLoopEventKind;
  at: string;
  noteId?: string;
  noteText?: string;
  entryId?: string;
  targetEntryId?: string;
  pastEntryId?: string;
  promptId?: string;
  bookmarkType?: string;
  source?: string;
  sourceId?: string;
  triggerEventId?: string;
}

export interface NoteRevisitLink {
  noteId: string;
  noteText: string;
  clicks: number;
  oldEntryOpens: number;
  bookmarks: number;
  copies: number;
  day1Returns: number;
  day7Returns: number;
}

export interface RevisitToReflectionLink {
  entryId: string;
  revisitedAt: string;
  sources: string;
  reflectionEntryId?: string;
  reflectionAt?: string;
  noteId?: string;
}

export interface CallbackBookmarkLink {
  noteId: string;
  noteText: string;
  bookmarkCount: number;
  entryIds: string[];
}

export interface CopiedMomentLink {
  noteId: string;
  noteText: string;
  count: number;
  sourceIds: string[];
}

export interface ReturnIndicatorRow {
  triggerKind: RetentionLoopEventKind;
  noteId?: string;
  noteText?: string;
  at: string;
  returnedDay1: boolean;
  returnedDay7: boolean;
}

export interface RetentionLoopScores {
  archiveAliveScore: number;
  revisitRewardScore: number;
  followUpContinuationScore: number;
}

export interface RetentionLoopReport {
  events: RetentionLoopEvent[];
  notesCausingRevisits: NoteRevisitLink[];
  revisitsCausingReflections: RevisitToReflectionLink[];
  callbacksCausingBookmarks: CallbackBookmarkLink[];
  copiedMomentsByNote: CopiedMomentLink[];
  returnIndicators: {
    day1Count: number;
    day7Count: number;
    rows: ReturnIndicatorRow[];
  };
  scores: RetentionLoopScores;
  hasData: boolean;
}

const LOOPS_KEY = "voicememory_retention_loops";
const FOLLOWUP_CONTEXT_KEY = "voicememory_retention_followup_context";
const NOTE_CONTEXT_KEY = "voicememory_retention_note_context";
const MAX_EVENTS = 800;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readEvents(): RetentionLoopEvent[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(LOOPS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as RetentionLoopEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEvents(events: RetentionLoopEvent[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(LOOPS_KEY, JSON.stringify(events.slice(-MAX_EVENTS)));
}

function pushEvent(event: Omit<RetentionLoopEvent, "id" | "at"> & { at?: string }): RetentionLoopEvent {
  const row: RetentionLoopEvent = {
    id: `loop-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    at: event.at ?? new Date().toISOString(),
    ...event,
  };
  const events = readEvents();
  events.push(row);
  writeEvents(events);
  return row;
}

function noteLabel(noteId?: string, noteText?: string): string {
  if (noteText?.trim()) return noteText.trim();
  if (noteId) return noteId;
  return "unknown note";
}

/** Remember which memory note was last touched for an entry — internal only. */
export function rememberNoteContext(
  entryId: string,
  noteId: string,
  noteText?: string,
): void {
  if (!isBrowser()) return;
  try {
    const raw = sessionStorage.getItem(NOTE_CONTEXT_KEY);
    const map = raw ? (JSON.parse(raw) as Record<string, { noteId: string; noteText?: string }>) : {};
    map[entryId] = { noteId, noteText };
    sessionStorage.setItem(NOTE_CONTEXT_KEY, JSON.stringify(map));
  } catch {
    // ignore
  }
}

export function resolveNoteContext(entryId: string): { noteId?: string; noteText?: string } {
  if (!isBrowser()) return {};
  try {
    const raw = sessionStorage.getItem(NOTE_CONTEXT_KEY);
    if (!raw) return {};
    const map = JSON.parse(raw) as Record<string, { noteId: string; noteText?: string }>;
    return map[entryId] ?? {};
  } catch {
    return {};
  }
}

export function storeFollowupLoopContext(noteId: string, promptId: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(
    FOLLOWUP_CONTEXT_KEY,
    JSON.stringify({ noteId, promptId, startedAt: new Date().toISOString() }),
  );
}

export function consumeFollowupLoopContext(): {
  noteId: string;
  promptId: string;
  startedAt: string;
} | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(FOLLOWUP_CONTEXT_KEY);
    sessionStorage.removeItem(FOLLOWUP_CONTEXT_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as { noteId: string; promptId: string; startedAt: string };
  } catch {
    return null;
  }
}

export function peekFollowupLoopContext(): {
  noteId: string;
  promptId: string;
} | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(FOLLOWUP_CONTEXT_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { noteId: string; promptId: string };
    return { noteId: parsed.noteId, promptId: parsed.promptId };
  } catch {
    return null;
  }
}

export function trackEntryRevisited(
  entryId: string,
  sources: string[],
  noteId?: string,
): void {
  pushEvent({
    kind: "entry_revisited",
    entryId,
    source: sources.join(","),
    noteId,
  });
  checkVoluntaryReturns(entryId);
}

export function trackResurfacedMemoryClicked(input: {
  noteId: string;
  noteText?: string;
  targetEntryId: string;
  source?: string;
}): void {
  rememberNoteContext(input.targetEntryId, input.noteId, input.noteText);
  pushEvent({
    kind: "resurfaced_memory_clicked",
    noteId: input.noteId,
    noteText: input.noteText,
    targetEntryId: input.targetEntryId,
    source: input.source,
  });
}

export function trackOldEntryOpenedFromNote(input: {
  noteId: string;
  noteText?: string;
  pastEntryId: string;
  source?: string;
}): void {
  rememberNoteContext(input.pastEntryId, input.noteId, input.noteText);
  pushEvent({
    kind: "old_entry_opened_from_note",
    noteId: input.noteId,
    noteText: input.noteText,
    pastEntryId: input.pastEntryId,
    targetEntryId: input.pastEntryId,
    source: input.source,
  });
}

export function trackBookmarkCreated(
  entryId: string,
  bookmarkType: string,
  noteId?: string,
  noteText?: string,
): void {
  const context = noteId ? { noteId, noteText } : resolveNoteContext(entryId);
  pushEvent({
    kind: "bookmark_created",
    entryId,
    bookmarkType,
    noteId: context.noteId,
    noteText: context.noteText,
  });
}

export function trackFollowupRecordingStarted(noteId: string, promptId: string): void {
  storeFollowupLoopContext(noteId, promptId);
  pushEvent({
    kind: "followup_recording_started",
    noteId,
    promptId,
  });
}

export function trackFollowupRecordingCompleted(newEntryId: string): void {
  const context = consumeFollowupLoopContext();
  pushEvent({
    kind: "followup_recording_completed",
    entryId: newEntryId,
    noteId: context?.noteId,
    promptId: context?.promptId,
  });
  checkVoluntaryReturns(newEntryId);
}

export function trackCopiedMemoryMoment(input: {
  sourceId: string;
  source: string;
  noteId?: string;
  noteText?: string;
  entryId?: string;
}): void {
  const context =
    input.noteId !== undefined
      ? { noteId: input.noteId, noteText: input.noteText }
      : input.entryId
        ? resolveNoteContext(input.entryId)
        : {};
  pushEvent({
    kind: "copied_memory_moment",
    sourceId: input.sourceId,
    source: input.source,
    entryId: input.entryId,
    noteId: context.noteId ?? input.sourceId,
    noteText: context.noteText,
  });
}

function activeDayKeys(): string[] {
  const keys = new Set<string>();
  for (const entry of getAllEntries()) {
    keys.add(toDayKey(entry.createdAt));
  }
  for (const event of readLocalEvents()) {
    keys.add(toDayKey(event.at));
  }
  for (const event of readEvents()) {
    keys.add(toDayKey(event.at));
  }
  return [...keys].sort();
}

function hasActivityOnDay(dayKey: string): boolean {
  return activeDayKeys().includes(dayKey);
}

function recordReturnIfEligible(trigger: RetentionLoopEvent): void {
  const triggerDay = toDayKey(trigger.at);
  const day1 = addDaysToKey(triggerDay, 1);
  const day7 = addDaysToKey(triggerDay, 7);

  const returnedDay1 = hasActivityOnDay(day1);
  const returnedDay7 =
    returnedDay1 ||
    [...Array(6)].some((_, i) => hasActivityOnDay(addDaysToKey(triggerDay, i + 2)));

  const events = readEvents();
  const alreadyDay1 = events.some(
    (row) =>
      row.kind === "returned_next_day" &&
      row.triggerEventId === trigger.id,
  );
  const alreadyDay7 = events.some(
    (row) =>
      row.kind === "returned_within_7_days" &&
      row.triggerEventId === trigger.id,
  );

  if (returnedDay1 && !alreadyDay1) {
    pushEvent({
      kind: "returned_next_day",
      triggerEventId: trigger.id,
      noteId: trigger.noteId,
      noteText: trigger.noteText,
      entryId: trigger.entryId ?? trigger.targetEntryId,
    });
  }

  if (returnedDay7 && !alreadyDay7) {
    pushEvent({
      kind: "returned_within_7_days",
      triggerEventId: trigger.id,
      noteId: trigger.noteId,
      noteText: trigger.noteText,
      entryId: trigger.entryId ?? trigger.targetEntryId,
    });
  }
}

/** Re-evaluate day-1 / day-7 returns after new activity — internal only. */
export function checkVoluntaryReturns(_anchorEntryId?: string): void {
  if (!isBrowser()) return;
  const triggers = readEvents().filter((row) =>
    [
      "resurfaced_memory_clicked",
      "old_entry_opened_from_note",
      "entry_revisited",
      "followup_recording_completed",
    ].includes(row.kind),
  );
  for (const trigger of triggers) {
    const age = daysBetweenKeys(toDayKey(trigger.at), toDayKey(new Date().toISOString()));
    if (age >= 1 && age <= 14) {
      recordReturnIfEligible(trigger);
    }
  }
}

function groupNotesCausingRevisits(events: RetentionLoopEvent[]): NoteRevisitLink[] {
  const map = new Map<string, NoteRevisitLink>();

  for (const event of events) {
    if (
      event.kind !== "resurfaced_memory_clicked" &&
      event.kind !== "old_entry_opened_from_note"
    ) {
      continue;
    }
    if (!event.noteId) continue;

    const row =
      map.get(event.noteId) ??
      ({
        noteId: event.noteId,
        noteText: noteLabel(event.noteId, event.noteText),
        clicks: 0,
        oldEntryOpens: 0,
        bookmarks: 0,
        copies: 0,
        day1Returns: 0,
        day7Returns: 0,
      } satisfies NoteRevisitLink);

    if (event.kind === "resurfaced_memory_clicked") row.clicks += 1;
    if (event.kind === "old_entry_opened_from_note") row.oldEntryOpens += 1;
    map.set(event.noteId, row);
  }

  for (const event of events) {
    if (!event.noteId || !map.has(event.noteId)) continue;
    const row = map.get(event.noteId)!;
    if (event.kind === "bookmark_created") row.bookmarks += 1;
    if (event.kind === "copied_memory_moment") row.copies += 1;
    if (event.kind === "returned_next_day") row.day1Returns += 1;
    if (event.kind === "returned_within_7_days") row.day7Returns += 1;
  }

  return [...map.values()].sort(
    (a, b) =>
      b.clicks + b.oldEntryOpens + b.bookmarks + b.copies - (a.clicks + a.oldEntryOpens + a.bookmarks + a.copies),
  );
}

function buildRevisitToReflectionLinks(events: RetentionLoopEvent[]): RevisitToReflectionLink[] {
  const revisits = events.filter((row) => row.kind === "entry_revisited");
  const reflections = events.filter((row) => row.kind === "followup_recording_completed");
  const entries = getAllEntries().sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  return revisits.map((revisit) => {
    const revisitTime = new Date(revisit.at).getTime();
    const followup = reflections.find(
      (row) =>
        row.noteId === revisit.noteId &&
        new Date(row.at).getTime() >= revisitTime &&
        new Date(row.at).getTime() - revisitTime < 1000 * 60 * 60 * 24 * 14,
    );
    const newEntry = entries.find(
      (entry) =>
        new Date(entry.createdAt).getTime() > revisitTime &&
        new Date(entry.createdAt).getTime() - revisitTime < 1000 * 60 * 60 * 24 * 14,
    );

    return {
      entryId: revisit.entryId ?? "",
      revisitedAt: revisit.at,
      sources: revisit.source ?? "",
      reflectionEntryId: followup?.entryId ?? newEntry?.id,
      reflectionAt: followup?.at ?? newEntry?.createdAt,
      noteId: revisit.noteId,
    };
  });
}

function buildCallbackBookmarkLinks(events: RetentionLoopEvent[]): CallbackBookmarkLink[] {
  const map = new Map<string, CallbackBookmarkLink>();
  for (const event of events) {
    if (event.kind !== "bookmark_created" || !event.noteId) continue;
    const row =
      map.get(event.noteId) ??
      ({
        noteId: event.noteId,
        noteText: noteLabel(event.noteId, event.noteText),
        bookmarkCount: 0,
        entryIds: [],
      } satisfies CallbackBookmarkLink);
    row.bookmarkCount += 1;
    if (event.entryId && !row.entryIds.includes(event.entryId)) {
      row.entryIds.push(event.entryId);
    }
    map.set(event.noteId, row);
  }
  return [...map.values()].sort((a, b) => b.bookmarkCount - a.bookmarkCount);
}

function buildCopiedMomentLinks(events: RetentionLoopEvent[]): CopiedMomentLink[] {
  const map = new Map<string, CopiedMomentLink>();
  for (const event of events) {
    if (event.kind !== "copied_memory_moment") continue;
    const noteId = event.noteId ?? event.sourceId ?? "unknown";
    const row =
      map.get(noteId) ??
      ({
        noteId,
        noteText: noteLabel(noteId, event.noteText),
        count: 0,
        sourceIds: [],
      } satisfies CopiedMomentLink);
    row.count += 1;
    const sourceId = event.sourceId ?? event.entryId;
    if (sourceId && !row.sourceIds.includes(sourceId)) {
      row.sourceIds.push(sourceId);
    }
    map.set(noteId, row);
  }
  return [...map.values()].sort((a, b) => b.count - a.count);
}

function buildReturnIndicators(events: RetentionLoopEvent[]): ReturnIndicatorRow[] {
  const triggers = events.filter((row) =>
    ["resurfaced_memory_clicked", "old_entry_opened_from_note", "entry_revisited"].includes(
      row.kind,
    ),
  );
  const day1Ids = new Set(
    events.filter((row) => row.kind === "returned_next_day").map((row) => row.triggerEventId),
  );
  const day7Ids = new Set(
    events.filter((row) => row.kind === "returned_within_7_days").map((row) => row.triggerEventId),
  );

  return triggers.map((trigger) => ({
    triggerKind: trigger.kind,
    noteId: trigger.noteId,
    noteText: trigger.noteText,
    at: trigger.at,
    returnedDay1: day1Ids.has(trigger.id),
    returnedDay7: day7Ids.has(trigger.id),
  }));
}

function computeScores(events: RetentionLoopEvent[]): RetentionLoopScores {
  const revisits = events.filter((row) => row.kind === "entry_revisited").length;
  const clicks = events.filter((row) => row.kind === "resurfaced_memory_clicked").length;
  const bookmarks = events.filter((row) => row.kind === "bookmark_created").length;
  const copies = events.filter((row) => row.kind === "copied_memory_moment").length;
  const day7 = events.filter((row) => row.kind === "returned_within_7_days").length;
  const reflections = events.filter((row) => row.kind === "followup_recording_completed").length;
  const followupStarted = events.filter((row) => row.kind === "followup_recording_started").length;
  const followupCompleted = events.filter((row) => row.kind === "followup_recording_completed").length;

  const archiveAliveScore = Math.min(
    100,
    revisits * 6 +
      clicks * 8 +
      bookmarks * 12 +
      copies * 10 +
      day7 * 14 +
      reflections * 16,
  );

  const triggers = events.filter((row) =>
    ["resurfaced_memory_clicked", "old_entry_opened_from_note"].includes(row.kind),
  );
  const rewardedTriggers = new Set<string>();
  for (const trigger of triggers) {
    const windowEnd = new Date(trigger.at).getTime() + 1000 * 60 * 60 * 24 * 7;
    const rewarded = events.some((row) => {
      if (new Date(row.at).getTime() < new Date(trigger.at).getTime()) return false;
      if (new Date(row.at).getTime() > windowEnd) return false;
      if (row.noteId && trigger.noteId && row.noteId !== trigger.noteId) return false;
      return (
        row.kind === "bookmark_created" ||
        row.kind === "copied_memory_moment" ||
        row.kind === "followup_recording_completed" ||
        row.kind === "returned_within_7_days" ||
        row.kind === "returned_next_day"
      );
    });
    if (rewarded) rewardedTriggers.add(trigger.id);
  }

  const revisitRewardScore =
    triggers.length > 0 ? Math.round((rewardedTriggers.size / triggers.length) * 100) : 0;

  const followUpContinuationScore =
    followupStarted > 0 ? Math.round((followupCompleted / followupStarted) * 100) : 0;

  return {
    archiveAliveScore,
    revisitRewardScore,
    followUpContinuationScore,
  };
}

export function readRetentionLoopEvents(): RetentionLoopEvent[] {
  if (!isBrowser()) return [];
  checkVoluntaryReturns();
  return readEvents();
}

export function buildRetentionLoopReport(): RetentionLoopReport {
  checkVoluntaryReturns();
  const events = readEvents();
  const returnRows = buildReturnIndicators(events);

  return {
    events: [...events].sort(
      (a, b) => new Date(b.at).getTime() - new Date(a.at).getTime(),
    ),
    notesCausingRevisits: groupNotesCausingRevisits(events),
    revisitsCausingReflections: buildRevisitToReflectionLinks(events),
    callbacksCausingBookmarks: buildCallbackBookmarkLinks(events),
    copiedMomentsByNote: buildCopiedMomentLinks(events),
    returnIndicators: {
      day1Count: events.filter((row) => row.kind === "returned_next_day").length,
      day7Count: events.filter((row) => row.kind === "returned_within_7_days").length,
      rows: returnRows,
    },
    scores: computeScores(events),
    hasData: events.length > 0,
  };
}

export function clearRetentionLoopEvents(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(LOOPS_KEY);
  sessionStorage.removeItem(FOLLOWUP_CONTEXT_KEY);
  sessionStorage.removeItem(NOTE_CONTEXT_KEY);
}

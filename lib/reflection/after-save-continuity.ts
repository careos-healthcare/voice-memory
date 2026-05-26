import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readLocalEvents } from "@/lib/local-analytics";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import {
  consumeRecordReturnContinuityLine,
  RECORD_RETURN_SAVED_LINE,
  storeRecordReturnContinuityLine,
} from "@/lib/reflection/record-return";
import { daysSinceLastReflection } from "@/lib/resurfacing/behavioral-ranking";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { RecordReturnContext } from "@/types/record-return";

export type AfterSaveContinuityKind =
  | "return_different_words"
  | "similar_words"
  | "open_loop"
  | "quote_resurfaced"
  | "days_return";

export interface AfterSaveContinuityLine {
  kind: AfterSaveContinuityKind;
  text: string;
}

const DEFERRED_KEY = "voicememory_after_save_continuity";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function similarWordsLine(
  entry: JournalEntry,
  entries: JournalEntry[],
): AfterSaveContinuityLine | null {
  const themes = entry.reflection.recurringThemes.filter(Boolean);
  if (themes.length === 0) return null;

  const prior = entries
    .filter((row) => row.id !== entry.id && new Date(row.createdAt) < new Date(entry.createdAt))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
  if (!prior) return null;

  const shared = prior.reflection.recurringThemes.filter((theme) =>
    themes.some((t) => t.toLowerCase() === theme.toLowerCase()),
  );
  if (shared.length === 0) return null;

  const gap = daysBetweenKeys(toDayKey(prior.createdAt), toDayKey(entry.createdAt));
  if (gap < 3) return null;

  return {
    kind: "similar_words",
    text: `You used similar words again ${gap} days later.`,
  };
}

function openLoopLine(entryId: string): AfterSaveContinuityLine | null {
  const linked = readLocalEvents().find(
    (event) =>
      event.name === OPEN_LOOP_EVENTS.reflectionAfterResurface &&
      event.meta?.entryId === entryId,
  );
  if (!linked) return null;
  return {
    kind: "open_loop",
    text: "This reflection linked to something you left open.",
  };
}

function daysReturnLine(noteId: string): AfterSaveContinuityLine | null {
  const gap = daysSinceLastReflection(noteId);
  if (gap == null || gap < 4) return null;
  return {
    kind: "days_return",
    text: `This came back after ${gap} days.`,
  };
}

/** Pick at most one continuity line after save — never stack modules. */
export function pickAfterSaveContinuityLine(
  entry: JournalEntry,
  returnContext: RecordReturnContext | null,
): AfterSaveContinuityLine | null {
  if (returnContext) {
    return {
      kind: "return_different_words",
      text: RECORD_RETURN_SAVED_LINE,
    };
  }

  const entries = getMemoryEligibleEntries();
  const candidates: AfterSaveContinuityLine[] = [];

  const similar = similarWordsLine(entry, entries);
  if (similar) candidates.push(similar);

  const loop = openLoopLine(entry.id);
  if (loop) candidates.push(loop);

  const lastCallback = readLocalEvents().find(
    (event) => event.name === CALLBACK_LEARNING_EVENTS.shown,
  );
  if (lastCallback?.meta?.noteId) {
    const days = daysReturnLine(lastCallback.meta.noteId);
    if (days) candidates.push(days);
  }

  return candidates[0] ?? null;
}

export function storeAfterSaveContinuityLine(line: AfterSaveContinuityLine): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(DEFERRED_KEY, JSON.stringify(line));
}

export function consumeAfterSaveContinuityLine(): AfterSaveContinuityLine | null {
  const returnLine = consumeRecordReturnContinuityLine();
  if (returnLine) {
    return { kind: "return_different_words", text: returnLine };
  }
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(DEFERRED_KEY);
    if (!raw) return null;
    sessionStorage.removeItem(DEFERRED_KEY);
    return JSON.parse(raw) as AfterSaveContinuityLine;
  } catch {
    return null;
  }
}

export function finalizeAfterSaveContinuity(
  entry: JournalEntry,
  returnContext: RecordReturnContext | null,
): void {
  const line = pickAfterSaveContinuityLine(entry, returnContext);
  if (!line) return;
  if (line.kind === "return_different_words") {
    storeRecordReturnContinuityLine(line.text);
  } else {
    storeAfterSaveContinuityLine(line);
  }
}

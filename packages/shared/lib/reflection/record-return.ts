import { storeContinuationMeta } from "@/lib/conversation/continuation-loops";
import { classifyResurfacingReturnMode } from "@/lib/resurfacing/return-modes";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { recordFollowUpPrompt } from "@/lib/sync/cross-device-continuity";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { MemoryNote } from "@/types/memory-note";
import type { RecordReturnContext, RecordReturnSource } from "@/types/record-return";

export const RECORD_RETURN_KEY = "voicememory_record_return";
export const RECORD_RETURN_CONTINUITY_KEY = "voicememory_record_return_continuity";

export const RECORD_RETURN_HEADING = "You're returning to this:";
export const RECORD_RETURN_SAVED_LINE =
  "You returned to this in different words.";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function anchorFromNote(note: MemoryNote): string {
  const quote =
    note.pastQuote?.trim() ||
    note.currentQuote?.trim() ||
    note.text.trim();
  return quote.slice(0, 220);
}

export function buildRecordReturnFromFollowup(prompt: FollowupPrompt): RecordReturnContext {
  const anchor =
    prompt.noteText?.trim() || prompt.text.trim();
  return {
    id: `return-${prompt.id}`,
    anchorQuote: anchor.slice(0, 220),
    noteId: prompt.noteId,
    source: prompt.source,
    promptId: prompt.id,
  };
}

export function buildRecordReturnFromNote(
  note: MemoryNote,
  source: RecordReturnSource = "primary_callback",
): RecordReturnContext {
  const entries = getMemoryEligibleEntries();
  return {
    id: `return-${source}-${note.id}`,
    anchorQuote: anchorFromNote(note),
    noteId: note.id,
    source,
    pastEntryId: note.pastEntryId ?? note.entryId,
    returnMode: classifyResurfacingReturnMode(note, entries),
  };
}

export function buildRecordReturnFromOpenLoop(input: {
  openLoopId: string;
  anchorQuote: string;
  sourceEntryId: string;
}): RecordReturnContext {
  return {
    id: `return-open-loop-${input.openLoopId}`,
    anchorQuote: input.anchorQuote.trim().slice(0, 220),
    noteId: input.openLoopId,
    source: "open_loop",
    openLoopId: input.openLoopId,
    pastEntryId: input.sourceEntryId,
  };
}

export function storeRecordReturnContext(context: RecordReturnContext): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(RECORD_RETURN_KEY, JSON.stringify(context));
  storeContinuationMeta(context.promptId ?? context.id, context.noteId);
  recordFollowUpPrompt({
    id: context.promptId ?? context.id,
    text: context.anchorQuote,
    noteId: context.noteId,
  });
}

export function peekRecordReturnContext(): RecordReturnContext | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(RECORD_RETURN_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<RecordReturnContext>;
    if (!parsed.id || !parsed.anchorQuote || !parsed.noteId || !parsed.source) return null;
    return parsed as RecordReturnContext;
  } catch {
    return null;
  }
}

export function consumeRecordReturnContext(): RecordReturnContext | null {
  const context = peekRecordReturnContext();
  if (!context || !isBrowser()) return context;
  sessionStorage.removeItem(RECORD_RETURN_KEY);
  return context;
}

export function storeRecordReturnContinuityLine(line: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(RECORD_RETURN_CONTINUITY_KEY, line);
}

export function consumeRecordReturnContinuityLine(): string | null {
  if (!isBrowser()) return null;
  const line = sessionStorage.getItem(RECORD_RETURN_CONTINUITY_KEY);
  if (line) sessionStorage.removeItem(RECORD_RETURN_CONTINUITY_KEY);
  return line;
}

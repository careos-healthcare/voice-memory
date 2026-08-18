import { trackLocalEvent } from "@/lib/local-analytics";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import {
  cadenceKey,
  classifyResurfacingReturnMode,
  emotionalStructureKey,
  RESURFACING_MODE_EVENTS,
} from "@/lib/resurfacing/return-modes";
import type { ResurfacingReturnMode } from "@/types/resurfacing-variety";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function resolveNote(
  note: MemoryNote | { id: string; text?: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
): { note: MemoryNote; entries: JournalEntry[] } | null {
  const pool = entries ?? getMemoryEligibleEntries();
  if ("text" in note && typeof note.text === "string" && note.text.trim()) {
    return { note: note as MemoryNote, entries: pool };
  }
  const stub: MemoryNote = {
    id: note.id,
    text: "",
    category: "returned",
    confidence: 0,
    entryId: note.entryId,
    pastEntryId: note.pastEntryId,
  };
  return { note: stub, entries: pool };
}

function modeMeta(
  mode: ResurfacingReturnMode,
  note: MemoryNote,
  extra?: Record<string, string>,
): Record<string, string> {
  const preview = note.text.trim().slice(0, 120);
  return {
    mode,
    noteId: note.id,
    preview,
    cadence: cadenceKey(preview),
    structure: emotionalStructureKey(note),
    ...extra,
  };
}

export function observeResurfacingModeShown(
  note: MemoryNote | { id: string; text?: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  extra?: Record<string, string>,
): ResurfacingReturnMode | null {
  if (!isBrowser() || isSideEffectBlocked()) return null;
  const resolved = resolveNote(note, entries);
  if (!resolved || !resolved.note.text.trim()) return null;
  const mode = classifyResurfacingReturnMode(resolved.note, resolved.entries);
  trackLocalEvent(RESURFACING_MODE_EVENTS.shown, {
    ...modeMeta(mode, resolved.note, extra),
  });
  return mode;
}

export function observeResurfacingModeOpened(
  note: MemoryNote | { id: string; text?: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  mode?: ResurfacingReturnMode,
): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const resolved = resolveNote(note, entries);
  if (!resolved) return;
  const resolvedMode =
    mode ?? classifyResurfacingReturnMode(resolved.note, resolved.entries);
  trackLocalEvent(RESURFACING_MODE_EVENTS.opened, modeMeta(resolvedMode, resolved.note));
}

export function observeReflectionAfterMode(
  note: MemoryNote | { id: string; text?: string; entryId?: string; pastEntryId?: string },
  entries?: JournalEntry[],
  mode?: ResurfacingReturnMode,
): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  const resolved = resolveNote(note, entries);
  if (!resolved) return;
  const resolvedMode =
    mode ?? classifyResurfacingReturnMode(resolved.note, resolved.entries);
  trackLocalEvent(RESURFACING_MODE_EVENTS.reflectionAfter, {
    ...modeMeta(resolvedMode, resolved.note),
  });
}

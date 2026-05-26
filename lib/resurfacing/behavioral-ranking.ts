import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { getResurfacingFatiguePenalty } from "@/lib/resurfacing/resurfacing-fatigue";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const REFLECTION_EVENT_NAMES = new Set<string>([
  "reflection_after_callback",
  "callback_opened",
  "callback_reread",
  OPEN_LOOP_EVENTS.reflectionAfterResurface,
  OPEN_LOOP_EVENTS.returnPromptEngaged,
]);

function reflectionCountForNote(noteId: string): number {
  return readLocalEvents().filter((event) => {
    if (!REFLECTION_EVENT_NAMES.has(event.name)) return false;
    const metaId = event.meta?.noteId ?? event.meta?.openLoopId ?? "";
    return metaId === noteId || metaId.includes(noteId);
  }).length;
}

function openLoopContinuationBoost(noteId: string): number {
  return readLocalEvents().filter(
    (event) =>
      event.name === OPEN_LOOP_EVENTS.reflectionAfterResurface &&
      event.meta?.openLoopId === noteId,
  ).length;
}

/** Score from observed reflection and continuation — not copy quality. */
export function behavioralResurfacingScore(noteId: string): number {
  const reflections = reflectionCountForNote(noteId);
  const loopBoost = openLoopContinuationBoost(noteId);
  const fatiguePenalty = getResurfacingFatiguePenalty(noteId);
  const score = reflections * 14 + loopBoost * 18;
  return Math.max(-48, score - fatiguePenalty);
}

export function applyBehavioralRankingBoost(
  note: MemoryNote,
  _entries: JournalEntry[],
  baseScore: number,
): number {
  return baseScore + Math.round(behavioralResurfacingScore(note.id) * 0.4);
}

export function rankNotesByBehavioralSignal(notes: MemoryNote[]): MemoryNote[] {
  return [...notes].sort(
    (a, b) => behavioralResurfacingScore(b.id) - behavioralResurfacingScore(a.id),
  );
}

export function daysSinceLastReflection(noteId: string): number | null {
  const events = readLocalEvents()
    .filter(
      (event) =>
        event.name === "reflection_after_callback" &&
        (event.meta?.noteId === noteId || event.meta?.noteId?.includes(noteId)),
    )
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
  const last = events[0]?.at;
  if (!last) return null;
  return daysBetweenKeys(toDayKey(last), toDayKey(new Date().toISOString()));
}

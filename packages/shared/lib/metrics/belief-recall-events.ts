import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { BeliefRecallLevelId } from "@/types/belief-recall";

export const BELIEF_RECALL_EVENT_NAMES = {
  level: "belief_recall_level" as const,
  note: "belief_recall_note" as const,
};

export function trackBeliefRecallLevel(meta: {
  level: BeliefRecallLevelId;
  attributionId: string;
  theoryId: string;
}): void {
  trackLocalEvent(BELIEF_RECALL_EVENT_NAMES.level, {
    level: meta.level,
    attributionId: meta.attributionId,
    theoryId: meta.theoryId,
  });
}

export function trackBeliefRecallNote(meta: {
  attributionId: string;
  noteLength: number;
}): void {
  trackLocalEvent(BELIEF_RECALL_EVENT_NAMES.note, {
    attributionId: meta.attributionId,
    noteLength: String(meta.noteLength),
  });
}

export function clearBeliefRecallEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(BELIEF_RECALL_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}

import { trackLocalEvent } from "@/lib/local-analytics";
import type { TheoryEventName, TheoryEventRecord } from "@/types/theory";

const EVENTS_KEY = "voicememory_theory_events";

export const THEORY_EVENTS = {
  viewed: "theory_viewed",
  expanded: "theory_expanded",
  revisited: "theory_revisited",
  feedbackSubmitted: "theory_feedback_submitted",
  discoverOpened: "discover_opened",
  theoryChangeClicked: "theory_change_clicked",
  theoryChangeExpanded: "theory_change_expanded",
} as const satisfies Record<string, TheoryEventName>;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `te-${Date.now()}`;
}

function readStored(): TheoryEventRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as TheoryEventRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeStored(events: TheoryEventRecord[]): void {
  getStorage()?.setItem(EVENTS_KEY, JSON.stringify(events.slice(-1000)));
}

export function trackTheoryEvent(
  name: TheoryEventName,
  meta?: Record<string, string>,
): TheoryEventRecord {
  const record: TheoryEventRecord = {
    id: newId(),
    name,
    theoryId: meta?.theoryId,
    at: new Date().toISOString(),
    meta,
  };
  const events = readStored();
  events.push(record);
  writeStored(events);
  trackLocalEvent(name, meta);
  return record;
}

export function readAllTheoryEvents(): TheoryEventRecord[] {
  return readStored();
}

export function appendTheoryEventForEval(
  name: TheoryEventName,
  meta?: Record<string, string>,
): void {
  trackTheoryEvent(name, meta);
}

export function clearTheoryEventsForEval(): void {
  getStorage()?.removeItem(EVENTS_KEY);
}

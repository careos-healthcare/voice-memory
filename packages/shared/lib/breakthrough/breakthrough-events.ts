import type {
  BreakthroughAttribution,
  BreakthroughEvent,
  BreakthroughPromptAnswer,
  BreakthroughType,
} from "@/types/breakthrough-tracking";

export const BREAKTHROUGH_EVENTS_KEY = "voicememory_breakthrough_events";

const MAX_EVENTS = 500;

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
  return `brk-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function normalize(raw: unknown): BreakthroughEvent | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.breakthroughId !== "string" || typeof row.type !== "string") return null;
  if (typeof row.createdAt !== "string" || typeof row.answer !== "string") return null;
  if (typeof row.promptId !== "string") return null;

  return {
    breakthroughId: row.breakthroughId,
    type: row.type as BreakthroughType,
    relatedTheoryId:
      typeof row.relatedTheoryId === "string" ? row.relatedTheoryId : undefined,
    relatedBlindSpotId:
      typeof row.relatedBlindSpotId === "string" ? row.relatedBlindSpotId : undefined,
    note: typeof row.note === "string" ? row.note : undefined,
    createdAt: row.createdAt,
    answer: row.answer as BreakthroughPromptAnswer,
    promptId: row.promptId,
    attribution:
      row.attribution && typeof row.attribution === "object"
        ? (row.attribution as BreakthroughAttribution)
        : {},
  };
}

export function readAllBreakthroughEvents(): BreakthroughEvent[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BREAKTHROUGH_EVENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((e): e is BreakthroughEvent => Boolean(e))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  } catch {
    return [];
  }
}

export function saveBreakthroughEvent(input: {
  type: BreakthroughType;
  answer: BreakthroughPromptAnswer;
  promptId: string;
  relatedTheoryId?: string;
  relatedBlindSpotId?: string;
  note?: string;
  attribution?: BreakthroughAttribution;
}): BreakthroughEvent {
  const record: BreakthroughEvent = {
    breakthroughId: newId(),
    type: input.type,
    relatedTheoryId: input.relatedTheoryId,
    relatedBlindSpotId: input.relatedBlindSpotId,
    note: input.note?.trim() || undefined,
    createdAt: new Date().toISOString(),
    answer: input.answer,
    promptId: input.promptId,
    attribution: input.attribution ?? {},
  };

  const all = readAllBreakthroughEvents();
  all.unshift(record);
  getStorage()?.setItem(
    BREAKTHROUGH_EVENTS_KEY,
    JSON.stringify(all.slice(0, MAX_EVENTS)),
  );
  return record;
}

export function clearBreakthroughEventsForEval(): void {
  getStorage()?.removeItem(BREAKTHROUGH_EVENTS_KEY);
}

import { trackTheoryEvent, THEORY_EVENTS } from "@/lib/theories/theory-events";
import type {
  TheoryFeedbackReaction,
  TheoryFeedbackRecord,
  TheorySource,
} from "@/types/theory";

const STORAGE_KEY = "voicememory_theory_feedback";
const MAX_RECORDS = 500;

const VALID_REACTIONS = new Set<TheoryFeedbackReaction>([
  "feels_true",
  "partly_true",
  "not_true",
  "too_obvious",
  "surprising",
]);

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `tf-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function normalize(raw: unknown): TheoryFeedbackRecord | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.theoryId !== "string" || typeof row.statement !== "string") return null;
  if (
    typeof row.reaction !== "string" ||
    !VALID_REACTIONS.has(row.reaction as TheoryFeedbackReaction)
  ) {
    return null;
  }
  return {
    id: typeof row.id === "string" ? row.id : newId(),
    theoryId: row.theoryId,
    reaction: row.reaction as TheoryFeedbackReaction,
    at: typeof row.at === "string" ? row.at : new Date().toISOString(),
    statement: row.statement,
    source: (row.source as TheorySource) ?? "pattern",
    confidence: typeof row.confidence === "number" ? row.confidence : 0,
  };
}

function readAll(): TheoryFeedbackRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed.map(normalize).filter((r): r is TheoryFeedbackRecord => Boolean(r));
  } catch {
    return [];
  }
}

function writeAll(records: TheoryFeedbackRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-MAX_RECORDS)));
}

export function saveTheoryFeedback(input: {
  theoryId: string;
  reaction: TheoryFeedbackReaction;
  statement: string;
  source: TheorySource;
  confidence: number;
}): TheoryFeedbackRecord {
  const record: TheoryFeedbackRecord = {
    id: newId(),
    theoryId: input.theoryId,
    reaction: input.reaction,
    at: new Date().toISOString(),
    statement: input.statement,
    source: input.source,
    confidence: input.confidence,
  };
  const records = readAll();
  records.push(record);
  writeAll(records);

  trackTheoryEvent(THEORY_EVENTS.feedbackSubmitted, {
    theoryId: record.theoryId,
    reaction: record.reaction,
    source: record.source,
    confidence: String(record.confidence),
  });

  void import("@/lib/product/activation-metrics").then((mod) => {
    mod.observeStrongReactionFromTheory(record.reaction);
  });

  return record;
}

export function getLatestTheoryFeedback(theoryId: string): TheoryFeedbackReaction | undefined {
  const matches = readAll()
    .filter((r) => r.theoryId === theoryId)
    .sort((a, b) => b.at.localeCompare(a.at));
  return matches[0]?.reaction;
}

export function readAllTheoryFeedback(): TheoryFeedbackRecord[] {
  return readAll();
}

export function clearTheoryFeedbackForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

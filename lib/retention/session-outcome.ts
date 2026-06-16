import { trackLocalEvent } from "@/lib/local-analytics";
import type { SessionOutcome, SessionOutcomeRecord } from "@/types/retention-discovery";

const STORAGE_KEY = "voicememory_session_outcome_survey";
const SESSION_ASKED_KEY = "voicememory_session_outcome_asked";

export const SESSION_OUTCOME_LABELS: Record<SessionOutcome, string> = {
  yes_differently: "Yes, I see something differently",
  yes_clearer: "Yes, I feel clearer",
  somewhat: "Somewhat",
  not_really: "Not really",
};

export const SESSION_OUTCOME_OPTIONS: SessionOutcome[] = [
  "yes_differently",
  "yes_clearer",
  "somewhat",
  "not_really",
];

const OUTCOME_SCORE: Record<SessionOutcome, number> = {
  yes_differently: 1,
  yes_clearer: 1,
  somewhat: 0.5,
  not_really: 0,
};

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function getSessionStorage(): Storage | null {
  if (typeof window !== "undefined") return window.sessionStorage;
  if (typeof globalThis.sessionStorage !== "undefined") {
    return globalThis.sessionStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `so-${Date.now()}`;
}

function readAll(): SessionOutcomeRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as SessionOutcomeRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: SessionOutcomeRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-300)));
}

export function helpfulnessScore(outcome: SessionOutcome): number {
  return OUTCOME_SCORE[outcome];
}

export function shouldAskSessionOutcome(sessionNumber: number): boolean {
  const store = getSessionStorage();
  if (!store) return false;
  return store.getItem(`${SESSION_ASKED_KEY}:${sessionNumber}`) !== "1";
}

export function markSessionOutcomeAsked(sessionNumber: number): void {
  getSessionStorage()?.setItem(`${SESSION_ASKED_KEY}:${sessionNumber}`, "1");
}

export function saveSessionOutcome(input: {
  outcome: SessionOutcome;
  sessionNumber: number;
}): SessionOutcomeRecord {
  const record: SessionOutcomeRecord = {
    id: newId(),
    sessionNumber: input.sessionNumber,
    outcome: input.outcome,
    at: new Date().toISOString(),
  };
  const records = readAll();
  records.push(record);
  writeAll(records);
  trackLocalEvent("session_outcome_captured", {
    outcome: record.outcome,
    sessionNumber: String(record.sessionNumber),
    helpfulness: String(helpfulnessScore(record.outcome)),
  });
  return record;
}

export function readAllSessionOutcomes(): SessionOutcomeRecord[] {
  return readAll();
}

export function clearSessionOutcomesForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

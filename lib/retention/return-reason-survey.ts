import { trackLocalEvent } from "@/lib/local-analytics";
import { getStoredEntryCount } from "@/lib/storage";
import type { ReturnReason, ReturnReasonRecord } from "@/types/retention-discovery";

const STORAGE_KEY = "voicememory_return_reason_survey";
const SESSION_ASKED_KEY = "voicememory_return_reason_asked_session";

export const RETURN_REASON_LABELS: Record<ReturnReason, string> = {
  bothering_me: "Something is bothering me",
  decision: "I need to think through a decision",
  recurring_problem: "I want perspective on a recurring problem",
  review_past_thoughts: "I wanted to review past thoughts",
  curious_what_noticed: "I was curious what ArchiveMe noticed",
  habit: "Habit",
  other: "Other",
};

export const RETURN_REASON_OPTIONS: ReturnReason[] = [
  "bothering_me",
  "decision",
  "recurring_problem",
  "review_past_thoughts",
  "curious_what_noticed",
  "habit",
  "other",
];

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
  return `rr-${Date.now()}`;
}

function readAll(): ReturnReasonRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ReturnReasonRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: ReturnReasonRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-300)));
}

export function shouldAskReturnReasonThisSession(sessionNumber: number): boolean {
  const store = getSessionStorage();
  if (!store) return false;
  const key = `${SESSION_ASKED_KEY}:${sessionNumber}`;
  if (store.getItem(key) === "1") return false;
  return true;
}

export function markReturnReasonAskedThisSession(sessionNumber: number): void {
  getSessionStorage()?.setItem(`${SESSION_ASKED_KEY}:${sessionNumber}`, "1");
}

export function saveReturnReason(input: {
  reason: ReturnReason;
  otherText?: string;
  sessionNumber: number;
}): ReturnReasonRecord {
  const record: ReturnReasonRecord = {
    id: newId(),
    reason: input.reason,
    otherText: input.reason === "other" ? input.otherText?.trim() : undefined,
    sessionNumber: input.sessionNumber,
    at: new Date().toISOString(),
    archiveSize: getStoredEntryCount(),
  };
  const records = readAll();
  records.push(record);
  writeAll(records);
  trackLocalEvent("return_reason_captured", {
    reason: record.reason,
    sessionNumber: String(record.sessionNumber),
    archiveSize: String(record.archiveSize),
  });
  return record;
}

export function readAllReturnReasons(): ReturnReasonRecord[] {
  return readAll();
}

export function clearReturnReasonsForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

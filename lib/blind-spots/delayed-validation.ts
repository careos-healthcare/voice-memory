import { offerInsightOutcomeAfterDelayedValidation } from "@/lib/insights/insight-outcome-schedule";
import type { DelayedValidationRecord, DelayedValidationResponse } from "@/types/blind-spot-discovery";

const STORAGE_KEY = "voicememory_blind_spot_delayed_validation";
const FOLLOW_UP_DAYS = 7;

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
  return `dv-${Date.now()}`;
}

function readAll(): DelayedValidationRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as DelayedValidationRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: DelayedValidationRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-200)));
}

export function scheduleDelayedValidation(input: {
  feedbackId: string;
  reviewId: string;
  headline: string;
  reaction: "obvious" | "completely_wrong";
  reactedAt?: string;
}): DelayedValidationRecord {
  const reactedAt = input.reactedAt ?? new Date().toISOString();
  const due = new Date(reactedAt);
  due.setDate(due.getDate() + FOLLOW_UP_DAYS);

  const record: DelayedValidationRecord = {
    id: newId(),
    feedbackId: input.feedbackId,
    reviewId: input.reviewId,
    headline: input.headline,
    reaction: input.reaction,
    createdAt: reactedAt,
    dueAt: due.toISOString(),
  };

  const records = readAll().filter((r) => r.feedbackId !== input.feedbackId);
  records.push(record);
  writeAll(records);
  return record;
}

export function getDueDelayedValidations(now = new Date()): DelayedValidationRecord[] {
  const ts = now.getTime();
  return readAll().filter((r) => !r.response && new Date(r.dueAt).getTime() <= ts);
}

export function saveDelayedValidationResponse(
  id: string,
  response: DelayedValidationResponse,
): DelayedValidationRecord | null {
  const records = readAll();
  const index = records.findIndex((r) => r.id === id);
  if (index < 0) return null;
  records[index] = {
    ...records[index]!,
    response,
    respondedAt: new Date().toISOString(),
  };
  writeAll(records);
  const saved = records[index]!;
  offerInsightOutcomeAfterDelayedValidation(saved);
  return saved;
}

export function readAllDelayedValidations(): DelayedValidationRecord[] {
  return readAll();
}

export function clearDelayedValidationsForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

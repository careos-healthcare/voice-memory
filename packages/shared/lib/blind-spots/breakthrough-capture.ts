import type { BreakthroughCaptureRecord } from "@/types/blind-spot-discovery";

const STORAGE_KEY = "voicememory_blind_spot_breakthroughs";

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
  return `bt-${Date.now()}`;
}

function readAll(): BreakthroughCaptureRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as BreakthroughCaptureRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: BreakthroughCaptureRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-300)));
}

export function saveBreakthroughCapture(input: {
  feedbackId: string;
  reviewId: string;
  reaction: "surprising" | "uncomfortably_accurate";
  phrase: string;
}): BreakthroughCaptureRecord | null {
  const phrase = input.phrase.trim();
  if (phrase.length < 3) return null;

  const record: BreakthroughCaptureRecord = {
    id: newId(),
    feedbackId: input.feedbackId,
    reviewId: input.reviewId,
    reaction: input.reaction,
    phrase,
    at: new Date().toISOString(),
  };

  const records = readAll();
  records.push(record);
  writeAll(records);
  return record;
}

export function readAllBreakthroughCaptures(): BreakthroughCaptureRecord[] {
  return readAll();
}

export function clearBreakthroughCapturesForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";

export type FeedbackKind =
  | "entry_reflection"
  | "weekly_summary"
  | "memory_continuity";

export type FeedbackRating = "up" | "down";

export interface FeedbackRecord {
  id: string;
  kind: FeedbackKind;
  targetKey: string;
  rating: FeedbackRating;
  comment?: string;
  at: string;
}

const FEEDBACK_KEY = "voicememory_feedback";
const MAX_RECORDS = 200;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function loadFeedback(): FeedbackRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(FEEDBACK_KEY);
    return raw ? (JSON.parse(raw) as FeedbackRecord[]) : [];
  } catch {
    return [];
  }
}

function saveFeedback(records: FeedbackRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(FEEDBACK_KEY, JSON.stringify(records.slice(-MAX_RECORDS)));
}

export function getFeedbackForTarget(
  kind: FeedbackKind,
  targetKey: string,
): FeedbackRecord | undefined {
  return loadFeedback().find(
    (record) => record.kind === kind && record.targetKey === targetKey,
  );
}

export function saveFeedbackRecord(input: {
  kind: FeedbackKind;
  targetKey: string;
  rating: FeedbackRating;
  comment?: string;
}): FeedbackRecord {
  const records = loadFeedback().filter(
    (record) =>
      !(record.kind === input.kind && record.targetKey === input.targetKey),
  );

  const record: FeedbackRecord = {
    id: crypto.randomUUID(),
    kind: input.kind,
    targetKey: input.targetKey,
    rating: input.rating,
    comment: input.comment?.trim() || undefined,
    at: new Date().toISOString(),
  };

  records.push(record);
  saveFeedback(records);

  trackLaunchEvent(LAUNCH_EVENTS.feedbackSubmitted, {
    kind: input.kind,
    rating: input.rating,
    hasComment: input.comment?.trim() ? "1" : "0",
  });

  return record;
}

export function readAllFeedback(): FeedbackRecord[] {
  return loadFeedback();
}

export function countFeedbackByRating(): { up: number; down: number } {
  const records = loadFeedback();
  return {
    up: records.filter((r) => r.rating === "up").length,
    down: records.filter((r) => r.rating === "down").length,
  };
}

export function clearAllFeedback(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(FEEDBACK_KEY);
}

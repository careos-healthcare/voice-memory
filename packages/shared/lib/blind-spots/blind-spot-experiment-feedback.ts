import type {
  BlindSpotExperimentFeedbackRating,
  BlindSpotExperimentFeedbackRecord,
  BlindSpotExperimentIngredient,
} from "@/types/blind-spot-experiment";

export const BLIND_SPOT_EXPERIMENT_FEEDBACK_KEY =
  "voicememory_blind_spot_experiment_feedback";

const MAX_RECORDS = 300;

const VALID_RATINGS = new Set<BlindSpotExperimentFeedbackRating>([
  "will_try",
  "not_useful",
  "already_tried",
]);

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `bsef-${Date.now()}`;
}

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function normalize(raw: unknown): BlindSpotExperimentFeedbackRecord | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.reviewId !== "string") return null;
  if (typeof row.rating !== "string" || !VALID_RATINGS.has(row.rating as BlindSpotExperimentFeedbackRating)) {
    return null;
  }
  if (typeof row.experimentIngredient !== "string") return null;
  return {
    id: typeof row.id === "string" ? row.id : newId(),
    reviewId: row.reviewId,
    experimentIngredient: row.experimentIngredient as BlindSpotExperimentIngredient,
    rating: row.rating as BlindSpotExperimentFeedbackRating,
    at: typeof row.at === "string" ? row.at : new Date().toISOString(),
  };
}

function readAll(): BlindSpotExperimentFeedbackRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BLIND_SPOT_EXPERIMENT_FEEDBACK_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed.map(normalize).filter((r): r is BlindSpotExperimentFeedbackRecord => Boolean(r));
  } catch {
    return [];
  }
}

function writeAll(records: BlindSpotExperimentFeedbackRecord[]): void {
  getStorage()?.setItem(
    BLIND_SPOT_EXPERIMENT_FEEDBACK_KEY,
    JSON.stringify(records.slice(-MAX_RECORDS)),
  );
}

export function getBlindSpotExperimentFeedback(
  reviewId: string,
): BlindSpotExperimentFeedbackRating | undefined {
  const matches = readAll()
    .filter((r) => r.reviewId === reviewId)
    .sort((a, b) => b.at.localeCompare(a.at));
  return matches[0]?.rating;
}

export function saveBlindSpotExperimentFeedback(input: {
  reviewId: string;
  experimentIngredient: BlindSpotExperimentIngredient;
  rating: BlindSpotExperimentFeedbackRating;
}): BlindSpotExperimentFeedbackRecord {
  const record: BlindSpotExperimentFeedbackRecord = {
    id: newId(),
    reviewId: input.reviewId,
    experimentIngredient: input.experimentIngredient,
    rating: input.rating,
    at: new Date().toISOString(),
  };
  const records = readAll();
  records.push(record);
  writeAll(records);
  return record;
}

export function readAllBlindSpotExperimentFeedback(): BlindSpotExperimentFeedbackRecord[] {
  return readAll();
}

export function clearBlindSpotExperimentFeedbackForEval(): void {
  getStorage()?.removeItem(BLIND_SPOT_EXPERIMENT_FEEDBACK_KEY);
}

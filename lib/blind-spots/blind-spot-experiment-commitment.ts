import { insightProfileFromBlindSpotReview } from "@/lib/breakthrough/breakthrough-attribution";
import { formatBlindSpotExperimentText } from "@/lib/blind-spots/blind-spot-experiment-text";
import { shouldShowBlindSpotExperiment } from "@/lib/blind-spots/blind-spot-experiment";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type {
  BlindSpotExperimentCommitment,
  ExperimentCommitmentStatus,
  ExperimentMetricIngredient,
} from "@/types/blind-spot-experiment-loop";
import type { BreakthroughInsightProfile } from "@/types/breakthrough-tracking";
import type { BlindSpotExperimentFeedbackRating } from "@/types/blind-spot-experiment";

export const BLIND_SPOT_EXPERIMENT_COMMITMENTS_KEY =
  "voicememory_blind_spot_experiment_commitments";

export const EXPERIMENT_FOLLOW_UP_DAYS = 7;

const MAX_RECORDS = 200;

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
  return `bsec-${Date.now()}`;
}

export function metricIngredientsFromProfile(
  profile: BreakthroughInsightProfile,
): ExperimentMetricIngredient[] {
  const tags: ExperimentMetricIngredient[] = [];
  if (profile.hasContradiction) tags.push("contradiction");
  if (profile.hasCostEvidence) tags.push("cost_evidence");
  if (profile.hasCrossLifeArea) tags.push("cross_life_area");
  if (profile.hasPredictionFailure) tags.push("failed_prediction");
  if (profile.hasLongTimeSpan) tags.push("long_span");
  return tags;
}

function dueAtFrom(createdAt: string): string {
  const due = new Date(createdAt);
  due.setDate(due.getDate() + EXPERIMENT_FOLLOW_UP_DAYS);
  return due.toISOString();
}

function normalize(raw: unknown): BlindSpotExperimentCommitment | null {
  if (!raw || typeof raw !== "object") return null;
  const row = raw as Record<string, unknown>;
  if (typeof row.commitmentId !== "string" || typeof row.reviewId !== "string") return null;
  if (typeof row.createdAt !== "string" || typeof row.dueAt !== "string") return null;
  if (typeof row.experimentText !== "string" || typeof row.headline !== "string") return null;

  const profile = row.insightProfile as BreakthroughInsightProfile | undefined;
  const metricIngredients = Array.isArray(row.metricIngredients)
    ? row.metricIngredients.filter((t): t is ExperimentMetricIngredient =>
        typeof t === "string",
      )
    : profile
      ? metricIngredientsFromProfile(profile)
      : [];

  return {
    commitmentId: row.commitmentId,
    reviewId: row.reviewId,
    blindSpotId: typeof row.blindSpotId === "string" ? row.blindSpotId : row.reviewId,
    headline: row.headline,
    experimentText: row.experimentText,
    experimentIngredient: row.experimentIngredient as BlindSpotExperimentCommitment["experimentIngredient"],
    metricIngredients,
    evidenceStrength: row.evidenceStrength as BlindSpotExperimentCommitment["evidenceStrength"],
    scorecardScore: typeof row.scorecardScore === "number" ? row.scorecardScore : 0,
    insightProfile: profile ?? {
      hasContradiction: metricIngredients.includes("contradiction"),
      hasPredictionFailure: metricIngredients.includes("failed_prediction"),
      hasCostEvidence: metricIngredients.includes("cost_evidence"),
      hasCrossLifeArea: metricIngredients.includes("cross_life_area"),
      hasLongTimeSpan: metricIngredients.includes("long_span"),
    },
    createdAt: row.createdAt,
    dueAt: row.dueAt,
    status: row.status as ExperimentCommitmentStatus,
    followUpAnswer: row.followUpAnswer as BlindSpotExperimentCommitment["followUpAnswer"],
    followUpAnsweredAt:
      typeof row.followUpAnsweredAt === "string" ? row.followUpAnsweredAt : undefined,
  };
}

export function readAllExperimentCommitments(): BlindSpotExperimentCommitment[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BLIND_SPOT_EXPERIMENT_COMMITMENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalize)
      .filter((r): r is BlindSpotExperimentCommitment => Boolean(r))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  } catch {
    return [];
  }
}

export function writeExperimentCommitments(
  records: BlindSpotExperimentCommitment[],
): void {
  getStorage()?.setItem(
    BLIND_SPOT_EXPERIMENT_COMMITMENTS_KEY,
    JSON.stringify(records.slice(0, MAX_RECORDS)),
  );
}

export function isEligibleForExperimentLoop(review: BlindSpotReviewResult): boolean {
  if (!review.experiment) return false;
  return shouldShowBlindSpotExperiment({
    evidenceStrength: review.evidenceStrength,
    scorecardScore: review.scorecard?.score,
  });
}

export function createExperimentCommitment(
  review: BlindSpotReviewResult,
  status: ExperimentCommitmentStatus = "pending",
): BlindSpotExperimentCommitment | null {
  if (!review.experiment || !isEligibleForExperimentLoop(review)) return null;

  const createdAt = new Date().toISOString();
  const insightProfile = insightProfileFromBlindSpotReview(review);

  const record: BlindSpotExperimentCommitment = {
    commitmentId: newId(),
    reviewId: review.reviewId,
    blindSpotId: review.reviewId,
    headline: review.headline,
    experimentText: formatBlindSpotExperimentText(review.experiment),
    experimentIngredient: review.experiment.ingredient,
    metricIngredients: metricIngredientsFromProfile(insightProfile),
    evidenceStrength: review.evidenceStrength,
    scorecardScore: review.scorecard?.score ?? 0,
    insightProfile,
    createdAt,
    dueAt: dueAtFrom(createdAt),
    status,
  };

  const all = readAllExperimentCommitments().filter((r) => r.reviewId !== review.reviewId);
  all.unshift(record);
  writeExperimentCommitments(all);
  return record;
}

export function applyExperimentFeedbackToCommitment(
  review: BlindSpotReviewResult,
  rating: BlindSpotExperimentFeedbackRating,
): BlindSpotExperimentCommitment | null {
  if (!isEligibleForExperimentLoop(review)) return null;

  if (rating === "will_try") {
    return createExperimentCommitment(review, "pending");
  }

  const createdAt = new Date().toISOString();
  const insightProfile = insightProfileFromBlindSpotReview(review);
  const status: ExperimentCommitmentStatus =
    rating === "already_tried" ? "tried" : "dismissed";

  const record: BlindSpotExperimentCommitment = {
    commitmentId: newId(),
    reviewId: review.reviewId,
    blindSpotId: review.reviewId,
    headline: review.headline,
    experimentText: formatBlindSpotExperimentText(review.experiment!),
    experimentIngredient: review.experiment!.ingredient,
    metricIngredients: metricIngredientsFromProfile(insightProfile),
    evidenceStrength: review.evidenceStrength,
    scorecardScore: review.scorecard?.score ?? 0,
    insightProfile,
    createdAt,
    dueAt: rating === "already_tried" ? dueAtFrom(createdAt) : createdAt,
    status,
  };

  const all = readAllExperimentCommitments().filter((r) => r.reviewId !== review.reviewId);
  all.unshift(record);
  writeExperimentCommitments(all);
  return record;
}

export function getDueExperimentFollowUps(
  now = new Date(),
): BlindSpotExperimentCommitment[] {
  const ts = now.getTime();
  return readAllExperimentCommitments().filter(
    (r) =>
      r.status === "pending" &&
      !r.followUpAnswer &&
      new Date(r.dueAt).getTime() <= ts,
  );
}

export function clearExperimentCommitmentsForEval(): void {
  getStorage()?.removeItem(BLIND_SPOT_EXPERIMENT_COMMITMENTS_KEY);
}

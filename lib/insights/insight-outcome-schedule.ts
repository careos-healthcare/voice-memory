import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import {
  insightOutcomeEventFromBlindSpotReview,
  insightOutcomeEventFromCommitment,
  insightOutcomeEventFromTheory,
} from "@/lib/insights/insight-outcome-attribution";
import { scheduleInsightOutcomeOffer } from "@/lib/insights/insight-outcome-storage";
import type { BlindSpotExperimentCommitment } from "@/types/blind-spot-experiment-loop";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { DelayedValidationRecord } from "@/types/blind-spot-discovery";
import type { InsightOutcomeTrigger } from "@/types/insight-outcome";
import type { Theory } from "@/types/theory";

export function offerInsightOutcomeAfterBlindSpotReview(
  review: BlindSpotReviewResult,
  trigger: InsightOutcomeTrigger,
): boolean {
  return scheduleInsightOutcomeOffer(insightOutcomeEventFromBlindSpotReview(review), trigger);
}

export function offerInsightOutcomeAfterCommitment(
  commitment: BlindSpotExperimentCommitment,
): boolean {
  return scheduleInsightOutcomeOffer(
    insightOutcomeEventFromCommitment(commitment),
    "experiment_followup",
  );
}

export function offerInsightOutcomeAfterTheory(theory: Theory): boolean {
  return scheduleInsightOutcomeOffer(insightOutcomeEventFromTheory(theory), "theory_revisit");
}

export function offerInsightOutcomeAfterDelayedValidation(
  record: DelayedValidationRecord,
): boolean {
  const feedback = readAllBlindSpotFeedback().find((f) => f.id === record.feedbackId);
  if (!feedback) return false;

  return scheduleInsightOutcomeOffer(
    {
      insightId: record.reviewId,
      insightType: "blind_spot",
      scorecardScore: feedback.estimatedImpactScore,
      contradictionPresent: false,
      costEvidencePresent: false,
      crossLifeAreaPresent: false,
      failedPredictionPresent: false,
      longSpanPresent: false,
      evidenceStrength: feedback.evidenceStrength,
      patternType: feedback.patternType,
      confidenceLabel: feedback.evidenceStrength.replace("_", " "),
    },
    "delayed_validation",
  );
}

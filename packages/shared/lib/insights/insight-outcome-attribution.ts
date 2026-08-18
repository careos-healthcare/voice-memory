import { patternTypeFromReviewId } from "@/lib/blind-spots/blind-spot-events";
import { insightProfileFromBlindSpotReview, insightProfileFromTheory } from "@/lib/breakthrough/breakthrough-attribution";
import type { BlindSpotExperimentCommitment } from "@/types/blind-spot-experiment-loop";
import type { BlindSpotReviewResult } from "@/types/blind-spot";
import type { InsightOutcomeEvent } from "@/types/insight-outcome";
import type { Theory } from "@/types/theory";

function profileFields(profile: {
  hasContradiction: boolean;
  hasPredictionFailure: boolean;
  hasCostEvidence: boolean;
  hasCrossLifeArea: boolean;
  hasLongTimeSpan: boolean;
}): Pick<
  InsightOutcomeEvent,
  | "contradictionPresent"
  | "costEvidencePresent"
  | "crossLifeAreaPresent"
  | "failedPredictionPresent"
  | "longSpanPresent"
> {
  return {
    contradictionPresent: profile.hasContradiction,
    costEvidencePresent: profile.hasCostEvidence,
    crossLifeAreaPresent: profile.hasCrossLifeArea,
    failedPredictionPresent: profile.hasPredictionFailure,
    longSpanPresent: profile.hasLongTimeSpan,
  };
}

export function insightOutcomeEventFromBlindSpotReview(
  review: BlindSpotReviewResult,
): Omit<InsightOutcomeEvent, "id" | "createdAt" | "outcome" | "respondedAt"> {
  const profile = insightProfileFromBlindSpotReview(review);
  return {
    insightId: review.reviewId,
    insightType: "blind_spot",
    scorecardScore: review.scorecard?.score ?? 0,
    ...profileFields(profile),
    evidenceStrength: review.evidenceStrength,
    patternType: patternTypeFromReviewId(review.reviewId),
    confidenceLabel: review.evidenceStrength.replace("_", " "),
  };
}

export function insightOutcomeEventFromTheory(
  theory: Theory,
): Omit<InsightOutcomeEvent, "id" | "createdAt" | "outcome" | "respondedAt"> {
  const profile = insightProfileFromTheory(theory);
  return {
    insightId: theory.id,
    insightType: "theory",
    scorecardScore: theory.scorecard?.score ?? 0,
    ...profileFields(profile),
    theoryType: theory.source,
    confidenceLabel: `${theory.confidence}% confidence`,
  };
}

export function insightOutcomeEventFromCommitment(
  commitment: BlindSpotExperimentCommitment,
): Omit<InsightOutcomeEvent, "id" | "createdAt" | "outcome" | "respondedAt"> {
  return {
    insightId: commitment.reviewId,
    insightType: "blind_spot",
    scorecardScore: commitment.scorecardScore,
    ...profileFields(commitment.insightProfile),
    evidenceStrength: commitment.evidenceStrength,
    patternType: patternTypeFromReviewId(commitment.reviewId),
    confidenceLabel: commitment.evidenceStrength.replace("_", " "),
  };
}

export function profileKeyForEvent(event: InsightOutcomeEvent): string {
  const flags = [
    event.contradictionPresent ? "c" : "",
    event.costEvidencePresent ? "$" : "",
    event.crossLifeAreaPresent ? "x" : "",
    event.failedPredictionPresent ? "p" : "",
    event.longSpanPresent ? "t" : "",
  ].join("");
  const subtype = event.insightType === "blind_spot" ? event.patternType ?? "pattern" : event.theoryType ?? "theory";
  return `${event.insightType}|${subtype}|${flags}|${event.evidenceStrength ?? "na"}`;
}

export function profileLabelForEvent(event: InsightOutcomeEvent): string {
  const parts: string[] = [event.insightType === "blind_spot" ? "Blind spot" : "Theory"];
  if (event.patternType) parts.push(event.patternType.replace(/_/g, " "));
  if (event.theoryType) parts.push(event.theoryType);
  if (event.contradictionPresent) parts.push("contradiction");
  if (event.costEvidencePresent) parts.push("cost");
  if (event.crossLifeAreaPresent) parts.push("cross-area");
  if (event.failedPredictionPresent) parts.push("prediction");
  if (event.longSpanPresent) parts.push("long span");
  return parts.join(" · ");
}

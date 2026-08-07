import { summarizeAgreement } from "./agreement";
import type { CompletedEvaluationRecord } from "./blind-review";
import type { HumanObservationCase } from "./research-domain";

export interface ResearchClaimsPolicy {
  schemaVersion: 1;
  policyVersion: string;
  precisionMarketingClaimsDefault: false;
  eligibleProvenance: "consented_human_submission";
  thresholds: {
    minimumHumanReviewedCases: number;
    minimumAggregateKappa: number;
    minimumEvidenceAgreement: number;
    minimumSafetyAgreement: number;
  };
}

export interface PrecisionClaimsDecision {
  precisionMarketingClaimsAllowed: boolean;
  policyVersion: string;
  eligibleHumanReviewedCases: number;
  scores: {
    aggregateKappa: number | null;
    evidenceAgreement: number | null;
    safetyAgreement: number | null;
  };
  blockedReasons: readonly (
    | "insufficient_human_cases"
    | "aggregate_agreement_below_threshold"
    | "evidence_agreement_below_threshold"
    | "safety_agreement_below_threshold"
  )[];
}

export function decidePrecisionMarketingClaims(input: {
  policy: ResearchClaimsPolicy;
  humanCases: readonly HumanObservationCase[];
  evaluations: readonly CompletedEvaluationRecord[];
}): PrecisionClaimsDecision {
  const humanById = new Map(
    input.humanCases.map((researchCase) => [researchCase.caseId, researchCase]),
  );
  const candidates = input.evaluations.filter((evaluation) => {
    const researchCase = humanById.get(evaluation.caseId);
    return (
      evaluation.reviewerCount >= 2 &&
      evaluation.reviewerCount === evaluation.labelSets.length &&
      evaluation.caseProvenance === input.policy.eligibleProvenance &&
      researchCase !== undefined &&
      evaluation.consentReceiptId === researchCase.consent.receiptId
    );
  });
  const byCase = new Map<string, CompletedEvaluationRecord[]>();
  for (const evaluation of candidates) {
    byCase.set(evaluation.caseId, [
      ...(byCase.get(evaluation.caseId) ?? []),
      evaluation,
    ]);
  }
  const eligible = [...byCase.values()].flatMap((records) =>
    records.length === 1 ? records : [],
  );
  const summary = summarizeAgreement(
    eligible.map((evaluation) => evaluation.labelSets),
  );
  const scores = {
    aggregateKappa: summary.aggregate.score,
    evidenceAgreement: summary.perCategory.supported.score,
    safetyAgreement: summary.perCategory.safe_to_show.score,
  };
  const blockedReasons: PrecisionClaimsDecision["blockedReasons"][number][] = [];
  const thresholds = input.policy.thresholds;
  if (eligible.length < thresholds.minimumHumanReviewedCases) {
    blockedReasons.push("insufficient_human_cases");
  }
  if (
    scores.aggregateKappa === null ||
    scores.aggregateKappa < thresholds.minimumAggregateKappa
  ) {
    blockedReasons.push("aggregate_agreement_below_threshold");
  }
  if (
    scores.evidenceAgreement === null ||
    scores.evidenceAgreement < thresholds.minimumEvidenceAgreement
  ) {
    blockedReasons.push("evidence_agreement_below_threshold");
  }
  if (
    scores.safetyAgreement === null ||
    scores.safetyAgreement < thresholds.minimumSafetyAgreement
  ) {
    blockedReasons.push("safety_agreement_below_threshold");
  }

  return {
    precisionMarketingClaimsAllowed: blockedReasons.length === 0,
    policyVersion: input.policy.policyVersion,
    eligibleHumanReviewedCases: eligible.length,
    scores,
    blockedReasons,
  };
}

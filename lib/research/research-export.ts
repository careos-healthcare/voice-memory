import { summarizeAgreement, type AgreementSummary } from "./agreement";
import type { CompletedEvaluationRecord } from "./blind-review";
import type {
  ConsentReceipt,
  HumanObservationCase,
  SyntheticObservationCase,
} from "./research-domain";

export interface ResearchExportBundle {
  schemaVersion: 1;
  exportedAt: string;
  syntheticCases: readonly SyntheticObservationCase[];
  humanCases: readonly HumanObservationCase[];
  evaluations: readonly CompletedEvaluationRecord[];
  agreementSummaries: {
    synthetic: AgreementSummary;
    consentedHuman: AgreementSummary;
  };
  consentMetadata: readonly ConsentReceipt[];
}

function byCaseId<T extends { caseId: string }>(left: T, right: T): number {
  return left.caseId.localeCompare(right.caseId);
}

function agreementFor(
  evaluations: readonly CompletedEvaluationRecord[],
): AgreementSummary {
  return summarizeAgreement(evaluations.map((record) => record.labelSets));
}

export function buildResearchExportBundle(input: {
  syntheticCases: readonly SyntheticObservationCase[];
  humanCases: readonly HumanObservationCase[];
  evaluations: readonly CompletedEvaluationRecord[];
  exportedAt: string;
}): ResearchExportBundle {
  const syntheticCases = [...input.syntheticCases].sort(byCaseId);
  const humanCases = [...input.humanCases].sort(byCaseId);
  const syntheticIds = new Set(syntheticCases.map((item) => item.caseId));
  const humanIds = new Set(humanCases.map((item) => item.caseId));

  const evaluations = input.evaluations
    .filter(
      (record) =>
        record.reviewerCount >= 2 &&
        ((record.caseProvenance === "synthetic" &&
          syntheticIds.has(record.caseId)) ||
          (record.caseProvenance === "consented_human_submission" &&
            humanIds.has(record.caseId))),
    )
    .sort(byCaseId);
  const syntheticEvaluations = evaluations.filter(
    (item) => item.caseProvenance === "synthetic",
  );
  const humanEvaluations = evaluations.filter(
    (item) => item.caseProvenance === "consented_human_submission",
  );

  return {
    schemaVersion: 1,
    exportedAt: new Date(input.exportedAt).toISOString(),
    syntheticCases,
    humanCases,
    evaluations,
    agreementSummaries: {
      synthetic: agreementFor(syntheticEvaluations),
      consentedHuman: agreementFor(humanEvaluations),
    },
    consentMetadata: humanCases
      .map((item) => ({ ...item.consent }))
      .sort((left, right) => left.receiptId.localeCompare(right.receiptId)),
  };
}

export function serializeResearchExport(bundle: ResearchExportBundle): string {
  return `${JSON.stringify(bundle, null, 2)}\n`;
}

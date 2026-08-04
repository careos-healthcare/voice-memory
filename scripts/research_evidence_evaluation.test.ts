import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import {
  cohenKappa,
  fleissKappa,
  summarizeAgreement,
  type CategoryDecision,
} from "../lib/research/agreement";
import {
  BlindReviewCoordinator,
  BlindReviewViolation,
  type CompletedEvaluationRecord,
} from "../lib/research/blind-review";
import {
  createHumanCase,
  createSyntheticCase,
  RESEARCH_FEEDBACK_CATEGORIES,
  ResearchPolicyViolation,
  type HumanObservationCase,
  type SyntheticObservationCase,
} from "../lib/research/research-domain";
import {
  buildResearchExportBundle,
  serializeResearchExport,
} from "../lib/research/research-export";
import { JsonResearchRepository } from "../lib/research/research-repository";
import {
  decidePrecisionMarketingClaims,
  type ResearchClaimsPolicy,
} from "../lib/research/precision-claims-policy";

const NOW = "2026-08-04T09:00:00.000Z";
const CATEGORIES = ["supported", "safe_to_show"] as const;

function syntheticCase(caseId = "synthetic-1"): SyntheticObservationCase {
  return createSyntheticCase({
    caseId,
    provenance: "synthetic",
    feedbackCategories: CATEGORIES,
    content: {
      observation: "A generated observation for evaluation.",
      evidence: ["Generated evidence A."],
    },
    createdAt: NOW,
  });
}

function humanCase(caseId = "human-1"): HumanObservationCase {
  return createHumanCase({
    caseId,
    provenance: "consented_human_submission",
    submissionProvenance: "explicit_case_submission",
    feedbackCategories: CATEGORIES,
    content: {
      observation: "A person explicitly submitted this observation.",
      evidence: ["Explicitly submitted evidence A."],
    },
    createdAt: NOW,
    consent: {
      receiptId: `consent-${caseId}`,
      policyVersion: "consent-v1",
      consentedAt: NOW,
      scope: "explicit_case_submission",
      explicitConsent: true,
    },
  });
}

function completedEvaluation(
  researchCase: SyntheticObservationCase | HumanObservationCase,
  labels: readonly CategoryDecision[] = [
    { supported: true, safe_to_show: true },
    { supported: true, safe_to_show: true },
  ],
): CompletedEvaluationRecord {
  return {
    schemaVersion: 1,
    evaluationId: `evaluation:${researchCase.caseId}`,
    caseId: researchCase.caseId,
    caseProvenance: researchCase.provenance,
    ...("consent" in researchCase
      ? { consentReceiptId: researchCase.consent.receiptId }
      : {}),
    reviewerCount: labels.length,
    labelSets: labels,
    agreement: summarizeAgreement([labels]),
    completedAt: NOW,
  };
}

test("domain accepts exactly the ten feedback categories", () => {
  const researchCase = createSyntheticCase({
    caseId: "all-categories",
    provenance: "synthetic",
    feedbackCategories: RESEARCH_FEEDBACK_CATEGORIES,
    content: { observation: "Synthetic", evidence: [] },
    createdAt: NOW,
  });
  assert.deepEqual(
    researchCase.feedbackCategories,
    RESEARCH_FEEDBACK_CATEGORIES,
  );
  assert.throws(
    () =>
      createSyntheticCase({
        caseId: "unknown-category",
        provenance: "synthetic",
        feedbackCategories: ["confidence_score"],
        content: { observation: "Synthetic", evidence: [] },
        createdAt: NOW,
      }),
    (error) =>
      error instanceof ResearchPolicyViolation &&
      error.code === "invalid_category",
  );
});

test("human queue rejects absent consent and automatic journal ingestion", () => {
  const valid = {
    caseId: "human-rejected",
    provenance: "consented_human_submission" as const,
    submissionProvenance: "explicit_case_submission" as const,
    feedbackCategories: CATEGORIES,
    content: { observation: "Submitted", evidence: [] },
    createdAt: NOW,
    consent: {
      receiptId: "receipt",
      policyVersion: "v1",
      consentedAt: NOW,
      scope: "explicit_case_submission" as const,
      explicitConsent: true as const,
    },
  };
  assert.throws(
    () =>
      createHumanCase({
        ...valid,
        consent: { ...valid.consent, explicitConsent: false },
      } as never),
    (error) =>
      error instanceof ResearchPolicyViolation &&
      error.code === "consent_required",
  );
  assert.throws(
    () => createHumanCase({ ...valid, automaticJournalImport: true } as never),
    (error) =>
      error instanceof ResearchPolicyViolation &&
      error.code === "automatic_import_forbidden",
  );
  assert.throws(
    () => createHumanCase({ ...valid, journalId: "private-entry" } as never),
    (error) =>
      error instanceof ResearchPolicyViolation &&
      error.code === "source_identifier_forbidden",
  );
});

test("JSON repository keeps synthetic and consented human files separate", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "research-repository-"));
  try {
    const repository = new JsonResearchRepository(root);
    const synthetic = syntheticCase();
    const human = humanCase();
    await repository.addSynthetic(synthetic);
    await repository.addHuman(human);

    assert.deepEqual(
      (await repository.listSynthetic()).map((item) => item.caseId),
      [synthetic.caseId],
    );
    assert.deepEqual(
      (await repository.listHuman()).map((item) => item.caseId),
      [human.caseId],
    );
    const syntheticFile = await readFile(
      repository.syntheticCasesPath,
      "utf8",
    );
    const humanFile = await readFile(repository.humanCasesPath, "utf8");
    assert.doesNotMatch(syntheticFile, /consent-human-1/);
    assert.doesNotMatch(humanFile, /synthetic-1/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("blind sessions isolate labels and enforce distinct one-time reviewers", () => {
  const researchCase = humanCase();
  const coordinator = new BlindReviewCoordinator(
    [researchCase],
    () => new Date(NOW),
  );
  const reviewerA = coordinator.beginReview(researchCase.caseId, "reviewer-a");
  assert.equal("labels" in reviewerA, false);
  const first = coordinator.submitReview({
    sessionToken: reviewerA.sessionToken,
    caseId: researchCase.caseId,
    reviewerId: "reviewer-a",
    labels: { supported: true, safe_to_show: true },
  });
  assert.equal(first, null);
  assert.throws(
    () => coordinator.getCompletedEvaluation(researchCase.caseId),
    (error) =>
      error instanceof BlindReviewViolation &&
      error.code === "labels_still_blinded",
  );
  assert.throws(
    () => coordinator.beginReview(researchCase.caseId, "reviewer-a"),
    (error) =>
      error instanceof BlindReviewViolation &&
      error.code === "duplicate_reviewer",
  );

  const reviewerB = coordinator.beginReview(researchCase.caseId, "reviewer-b");
  assert.equal("labels" in reviewerB, false);
  assert.throws(
    () =>
      coordinator.submitReview({
        sessionToken: reviewerB.sessionToken,
        caseId: "wrong-case",
        reviewerId: "reviewer-b",
        labels: { supported: true },
      }),
    (error) =>
      error instanceof BlindReviewViolation && error.code === "wrong_case",
  );
  const completed = coordinator.submitReview({
    sessionToken: reviewerB.sessionToken,
    caseId: researchCase.caseId,
    reviewerId: "reviewer-b",
    labels: { supported: true, safe_to_show: false },
  });
  assert.equal(completed?.reviewerCount, 2);
  assert.equal(JSON.stringify(completed).includes("reviewer-a"), false);
  assert.throws(
    () =>
      coordinator.submitReview({
        sessionToken: reviewerB.sessionToken,
        caseId: researchCase.caseId,
        reviewerId: "reviewer-b",
        labels: { supported: true },
      }),
    (error) =>
      error instanceof BlindReviewViolation && error.code === "token_replay",
  );
  assert.throws(
    () => coordinator.readReviewerDraft(),
    (error) =>
      error instanceof BlindReviewViolation &&
      error.code === "draft_access_forbidden",
  );
});

test("Cohen kappa covers known, chance, missing, and zero-variance cases", () => {
  const known = cohenKappa([
    [true, true],
    [true, true],
    [false, false],
    [true, false],
  ]);
  assert.equal(known.score, 0.5);
  assert.equal(
    cohenKappa([
      [true, true],
      [true, false],
      [false, true],
      [false, false],
    ]).score,
    0,
  );
  const missing = cohenKappa([
    [true, undefined],
    [false, false],
  ]);
  assert.equal(missing.sampleSize, 1);
  assert.equal(missing.score, 1);
  const zeroVariance = cohenKappa([
    [true, true],
    [true, true],
  ]);
  assert.equal(zeroVariance.score, 1);
  assert.equal(zeroVariance.status, "zero_variance_agreement");
  assert.equal(cohenKappa([[undefined, false]]).score, null);
});

test("Fleiss-compatible kappa is deterministic for additional reviewers", () => {
  const result = fleissKappa([
    [true, true, false],
    [true, true, true],
    [false, false, false],
    [true, false, false],
  ]);
  assert.ok(result.score !== null);
  assert.ok(Math.abs(result.score - 1 / 3) < 1e-12);
  assert.equal(
    summarizeAgreement([
      [
        { supported: true },
        { supported: true },
        { supported: false },
      ],
    ]).method,
    "fleiss_compatible",
  );
});

test("research export is deterministic, separated, and privacy-safe", () => {
  const synthetic = syntheticCase();
  const human = humanCase();
  const bundle = buildResearchExportBundle({
    syntheticCases: [synthetic],
    humanCases: [human],
    evaluations: [
      completedEvaluation(synthetic),
      completedEvaluation(human),
      {
        ...completedEvaluation(human),
        caseId: "unconsented-case",
        evaluationId: "evaluation:unconsented-case",
      },
    ],
    exportedAt: NOW,
  });
  const first = serializeResearchExport(bundle);
  const second = serializeResearchExport(
    buildResearchExportBundle({
      syntheticCases: [synthetic],
      humanCases: [human],
      evaluations: [
        completedEvaluation(synthetic),
        completedEvaluation(human),
      ],
      exportedAt: NOW,
    }),
  );
  assert.equal(first, second);
  assert.equal(bundle.syntheticCases.length, 1);
  assert.equal(bundle.humanCases.length, 1);
  assert.equal(bundle.evaluations.length, 2);
  assert.doesNotMatch(
    first,
    /reviewerId|reviewer-a|sessionToken|journalId|archiveId|accountId/,
  );
  assert.match(first, /"consentMetadata"/);
});

const TEST_POLICY: ResearchClaimsPolicy = {
  schemaVersion: 1,
  policyVersion: "test-policy",
  precisionMarketingClaimsDefault: false,
  eligibleProvenance: "consented_human_submission",
  thresholds: {
    minimumHumanReviewedCases: 2,
    minimumAggregateKappa: 0.6,
    minimumEvidenceAgreement: 0.7,
    minimumSafetyAgreement: 0.8,
  },
};

test("precision claims gate ignores synthetic scores and defaults blocked", () => {
  const synthetic = syntheticCase();
  const syntheticOnly = decidePrecisionMarketingClaims({
    policy: TEST_POLICY,
    humanCases: [],
    evaluations: [completedEvaluation(synthetic)],
  });
  assert.equal(syntheticOnly.precisionMarketingClaimsAllowed, false);
  assert.equal(syntheticOnly.eligibleHumanReviewedCases, 0);

  const humanA = humanCase("human-a");
  const oneHuman = decidePrecisionMarketingClaims({
    policy: TEST_POLICY,
    humanCases: [humanA],
    evaluations: [
      completedEvaluation(synthetic),
      completedEvaluation(humanA),
    ],
  });
  assert.equal(oneHuman.precisionMarketingClaimsAllowed, false);
  assert.ok(oneHuman.blockedReasons.includes("insufficient_human_cases"));

  const duplicateHumanRecord = decidePrecisionMarketingClaims({
    policy: { ...TEST_POLICY, thresholds: {
      ...TEST_POLICY.thresholds,
      minimumHumanReviewedCases: 1,
    } },
    humanCases: [humanA],
    evaluations: [
      completedEvaluation(humanA),
      completedEvaluation(humanA),
    ],
  });
  assert.equal(duplicateHumanRecord.eligibleHumanReviewedCases, 0);
  assert.equal(duplicateHumanRecord.precisionMarketingClaimsAllowed, false);
});

test("precision claims require human agreement across every threshold", () => {
  const humanA = humanCase("human-a");
  const humanB = humanCase("human-b");
  const allowed = decidePrecisionMarketingClaims({
    policy: TEST_POLICY,
    humanCases: [humanA, humanB],
    evaluations: [
      completedEvaluation(humanA),
      completedEvaluation(humanB),
    ],
  });
  assert.equal(allowed.precisionMarketingClaimsAllowed, true);

  const disputed = decidePrecisionMarketingClaims({
    policy: TEST_POLICY,
    humanCases: [humanA, humanB],
    evaluations: [
      completedEvaluation(humanA, [
        { supported: true, safe_to_show: true },
        { supported: false, safe_to_show: false },
      ]),
      completedEvaluation(humanB, [
        { supported: true, safe_to_show: true },
        { supported: false, safe_to_show: false },
      ]),
    ],
  });
  assert.equal(disputed.precisionMarketingClaimsAllowed, false);
  assert.ok(disputed.blockedReasons.length > 0);
});

test("machine-readable policy has conservative human-only defaults", async () => {
  const policy = JSON.parse(
    await readFile(
      path.join(
        process.cwd(),
        "config/research/research-policy.v1.json",
      ),
      "utf8",
    ),
  ) as ResearchClaimsPolicy;
  assert.equal(policy.precisionMarketingClaimsDefault, false);
  assert.equal(policy.eligibleProvenance, "consented_human_submission");
  assert.ok(policy.thresholds.minimumHumanReviewedCases >= 30);
  assert.ok(policy.thresholds.minimumAggregateKappa >= 0.6);
  assert.ok(policy.thresholds.minimumSafetyAgreement >= 0.8);
});

import { createHash, randomBytes } from "node:crypto";
import {
  RESEARCH_FEEDBACK_CATEGORIES,
  type ResearchFeedbackCategory,
  type ResearchObservationCase,
} from "./research-domain";
import {
  summarizeAgreement,
  type AgreementSummary,
  type CategoryDecision,
} from "./agreement";

export interface BlindReviewAssignment {
  caseId: string;
  content: ResearchObservationCase["content"];
  feedbackCategories: readonly ResearchFeedbackCategory[];
  sessionToken: string;
}

export interface CompletedEvaluationRecord {
  schemaVersion: 1;
  evaluationId: string;
  caseId: string;
  caseProvenance: ResearchObservationCase["provenance"];
  consentReceiptId?: string;
  reviewerCount: number;
  labelSets: readonly CategoryDecision[];
  agreement: AgreementSummary;
  completedAt: string;
}

interface ActiveSession {
  caseId: string;
  reviewerDigest: string;
}

export class BlindReviewViolation extends Error {
  constructor(
    message: string,
    readonly code:
      | "case_not_found"
      | "duplicate_reviewer"
      | "invalid_token"
      | "token_replay"
      | "wrong_case"
      | "wrong_reviewer"
      | "invalid_labels"
      | "labels_still_blinded"
      | "draft_access_forbidden",
  ) {
    super(message);
    this.name = "BlindReviewViolation";
  }
}

function digest(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function copyLabels(labels: CategoryDecision): CategoryDecision {
  return Object.fromEntries(Object.entries(labels)) as CategoryDecision;
}

export class BlindReviewCoordinator {
  private readonly cases = new Map<string, ResearchObservationCase>();
  private readonly activeSessions = new Map<string, ActiveSession>();
  private readonly usedTokens = new Set<string>();
  private readonly labelsByCase = new Map<string, Map<string, CategoryDecision>>();
  private readonly completedAtByCase = new Map<string, string>();

  constructor(
    cases: readonly ResearchObservationCase[],
    private readonly clock: () => Date = () => new Date(),
  ) {
    for (const researchCase of cases) {
      if (this.cases.has(researchCase.caseId)) {
        throw new Error(`Duplicate research case: ${researchCase.caseId}`);
      }
      this.cases.set(researchCase.caseId, researchCase);
    }
  }

  beginReview(caseId: string, reviewerId: string): BlindReviewAssignment {
    const researchCase = this.cases.get(caseId);
    if (!researchCase) {
      throw new BlindReviewViolation(
        `Research case not found: ${caseId}`,
        "case_not_found",
      );
    }
    if (!reviewerId.trim()) {
      throw new BlindReviewViolation(
        "Reviewer identity is required",
        "wrong_reviewer",
      );
    }
    const reviewerDigest = digest(reviewerId);
    const submitted = this.labelsByCase.get(caseId);
    const hasActiveSession = [...this.activeSessions.values()].some(
      (session) =>
        session.caseId === caseId &&
        session.reviewerDigest === reviewerDigest,
    );
    if (submitted?.has(reviewerDigest) || hasActiveSession) {
      throw new BlindReviewViolation(
        "A reviewer may label a case only once",
        "duplicate_reviewer",
      );
    }

    const sessionToken = randomBytes(32).toString("base64url");
    this.activeSessions.set(digest(sessionToken), {
      caseId,
      reviewerDigest,
    });
    return {
      caseId,
      content: {
        observation: researchCase.content.observation,
        evidence: [...researchCase.content.evidence],
        ...(researchCase.content.context === undefined
          ? {}
          : { context: researchCase.content.context }),
      },
      feedbackCategories: [...researchCase.feedbackCategories],
      sessionToken,
    };
  }

  submitReview(input: {
    sessionToken: string;
    caseId: string;
    reviewerId: string;
    labels: CategoryDecision;
  }): CompletedEvaluationRecord | null {
    const tokenDigest = digest(input.sessionToken);
    if (this.usedTokens.has(tokenDigest)) {
      throw new BlindReviewViolation(
        "Blind-review session token has already been used",
        "token_replay",
      );
    }
    const session = this.activeSessions.get(tokenDigest);
    if (!session) {
      throw new BlindReviewViolation(
        "Blind-review session token is invalid",
        "invalid_token",
      );
    }
    if (session.caseId !== input.caseId) {
      throw new BlindReviewViolation(
        "Blind-review session is bound to a different case",
        "wrong_case",
      );
    }
    if (session.reviewerDigest !== digest(input.reviewerId)) {
      throw new BlindReviewViolation(
        "Blind-review session is bound to a different reviewer",
        "wrong_reviewer",
      );
    }
    const researchCase = this.cases.get(input.caseId);
    if (!researchCase) {
      throw new BlindReviewViolation(
        `Research case not found: ${input.caseId}`,
        "case_not_found",
      );
    }
    this.validateLabels(researchCase, input.labels);

    this.activeSessions.delete(tokenDigest);
    this.usedTokens.add(tokenDigest);
    const labelsByReviewer =
      this.labelsByCase.get(input.caseId) ??
      new Map<string, CategoryDecision>();
    labelsByReviewer.set(session.reviewerDigest, copyLabels(input.labels));
    this.labelsByCase.set(input.caseId, labelsByReviewer);
    if (
      labelsByReviewer.size >= 2 &&
      !this.completedAtByCase.has(input.caseId)
    ) {
      this.completedAtByCase.set(input.caseId, this.clock().toISOString());
    }

    return labelsByReviewer.size >= 2
      ? this.completedRecord(researchCase, labelsByReviewer)
      : null;
  }

  getCompletedEvaluation(caseId: string): CompletedEvaluationRecord {
    const researchCase = this.cases.get(caseId);
    if (!researchCase) {
      throw new BlindReviewViolation(
        `Research case not found: ${caseId}`,
        "case_not_found",
      );
    }
    const labels = this.labelsByCase.get(caseId);
    if (!labels || labels.size < 2) {
      throw new BlindReviewViolation(
        "Labels remain blinded until two distinct reviewers submit",
        "labels_still_blinded",
      );
    }
    return this.completedRecord(researchCase, labels);
  }

  readReviewerDraft(): never {
    throw new BlindReviewViolation(
      "Reviewer drafts are private and cannot be read",
      "draft_access_forbidden",
    );
  }

  listCompletedEvaluations(): readonly CompletedEvaluationRecord[] {
    return [...this.cases.values()]
      .flatMap((researchCase) => {
        const labels = this.labelsByCase.get(researchCase.caseId);
        return labels && labels.size >= 2
          ? [this.completedRecord(researchCase, labels)]
          : [];
      })
      .sort((left, right) => left.caseId.localeCompare(right.caseId));
  }

  private validateLabels(
    researchCase: ResearchObservationCase,
    labels: CategoryDecision,
  ): void {
    if (!labels || typeof labels !== "object" || Array.isArray(labels)) {
      throw new BlindReviewViolation(
        "Review labels must be category decisions",
        "invalid_labels",
      );
    }
    const entries = Object.entries(labels);
    if (entries.length === 0) {
      throw new BlindReviewViolation(
        "At least one category decision is required",
        "invalid_labels",
      );
    }
    const allowed = new Set(researchCase.feedbackCategories);
    const known = new Set<string>(RESEARCH_FEEDBACK_CATEGORIES);
    for (const [category, decision] of entries) {
      if (!known.has(category) || !allowed.has(category as ResearchFeedbackCategory)) {
        throw new BlindReviewViolation(
          `Category is not applicable to this case: ${category}`,
          "invalid_labels",
        );
      }
      if (typeof decision !== "boolean") {
        throw new BlindReviewViolation(
          `Category decision must be boolean: ${category}`,
          "invalid_labels",
        );
      }
    }
  }

  private completedRecord(
    researchCase: ResearchObservationCase,
    labelsByReviewer: ReadonlyMap<string, CategoryDecision>,
  ): CompletedEvaluationRecord {
    const labelSets = [...labelsByReviewer.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([, labels]) => copyLabels(labels));
    return {
      schemaVersion: 1,
      evaluationId: `evaluation:${researchCase.caseId}`,
      caseId: researchCase.caseId,
      caseProvenance: researchCase.provenance,
      ...("consent" in researchCase
        ? { consentReceiptId: researchCase.consent.receiptId }
        : {}),
      reviewerCount: labelSets.length,
      labelSets,
      agreement: summarizeAgreement([labelSets]),
      completedAt:
        this.completedAtByCase.get(researchCase.caseId) ??
        this.clock().toISOString(),
    };
  }
}

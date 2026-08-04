export const RESEARCH_FEEDBACK_CATEGORIES = [
  "accepted_observations",
  "wrong_angle",
  "too_generic",
  "hidden",
  "useful",
  "not_useful",
  "supported",
  "unsupported",
  "evidence_mismatch",
  "safe_to_show",
] as const;

export type ResearchFeedbackCategory =
  (typeof RESEARCH_FEEDBACK_CATEGORIES)[number];

export type ResearchCaseProvenance =
  | "synthetic"
  | "consented_human_submission";

export interface ResearchCaseContent {
  observation: string;
  evidence: readonly string[];
  context?: string;
}

export interface ConsentReceipt {
  receiptId: string;
  policyVersion: string;
  consentedAt: string;
  scope: "explicit_case_submission";
  explicitConsent: true;
}

interface ResearchObservationCaseBase {
  schemaVersion: 1;
  caseId: string;
  feedbackCategories: readonly ResearchFeedbackCategory[];
  content: ResearchCaseContent;
  createdAt: string;
}

export interface SyntheticObservationCase extends ResearchObservationCaseBase {
  provenance: "synthetic";
}

export interface HumanObservationCase extends ResearchObservationCaseBase {
  provenance: "consented_human_submission";
  submissionProvenance: "explicit_case_submission";
  consent: ConsentReceipt;
}

export type ResearchObservationCase =
  | SyntheticObservationCase
  | HumanObservationCase;

export interface SyntheticCaseInput {
  caseId: string;
  feedbackCategories: readonly string[];
  content: ResearchCaseContent;
  createdAt: string;
  provenance: "synthetic";
}

export interface HumanCaseInput {
  caseId: string;
  feedbackCategories: readonly string[];
  content: ResearchCaseContent;
  createdAt: string;
  provenance: "consented_human_submission";
  submissionProvenance: "explicit_case_submission";
  consent: ConsentReceipt;
}

export class ResearchPolicyViolation extends Error {
  constructor(
    message: string,
    readonly code:
      | "invalid_case"
      | "invalid_category"
      | "consent_required"
      | "automatic_import_forbidden"
      | "source_identifier_forbidden",
  ) {
    super(message);
    this.name = "ResearchPolicyViolation";
  }
}

const SOURCE_IDENTIFIER_KEYS = new Set([
  "accountid",
  "archiveid",
  "journalid",
  "entryid",
  "momentid",
  "userid",
  "sourcejournalid",
  "sourcearchiveid",
]);

function normalizedKey(key: string): string {
  return key.replace(/[^a-z0-9]/gi, "").toLowerCase();
}

function assertNoIngestionMarkers(value: unknown, path = "case"): void {
  if (!value || typeof value !== "object") return;
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      assertNoIngestionMarkers(item, `${path}[${index}]`),
    );
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    const normalized = normalizedKey(key);
    if (
      normalized.includes("automaticimport") ||
      (normalized.startsWith("automatic") && normalized.includes("import")) ||
      (normalized.startsWith("auto") &&
        (normalized.includes("import") || normalized.includes("upload"))) ||
      normalized.includes("autoupload") ||
      normalized.includes("journalupload") ||
      normalized.includes("archiveupload")
    ) {
      throw new ResearchPolicyViolation(
        `Automatic journal or archive ingestion is forbidden (${path}.${key})`,
        "automatic_import_forbidden",
      );
    }
    if (SOURCE_IDENTIFIER_KEYS.has(normalized)) {
      throw new ResearchPolicyViolation(
        `Source identifier is forbidden (${path}.${key})`,
        "source_identifier_forbidden",
      );
    }
    assertNoIngestionMarkers(child, `${path}.${key}`);
  }
}

function assertNonEmptyString(value: unknown, field: string): asserts value is string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ResearchPolicyViolation(
      `${field} must be a non-empty string`,
      "invalid_case",
    );
  }
}

function validateCategories(
  categories: readonly string[],
): readonly ResearchFeedbackCategory[] {
  if (!Array.isArray(categories) || categories.length === 0) {
    throw new ResearchPolicyViolation(
      "At least one feedback category is required",
      "invalid_category",
    );
  }
  const allowed = new Set<string>(RESEARCH_FEEDBACK_CATEGORIES);
  const unique = [...new Set(categories)];
  for (const category of unique) {
    if (!allowed.has(category)) {
      throw new ResearchPolicyViolation(
        `Unknown research feedback category: ${category}`,
        "invalid_category",
      );
    }
  }
  return unique as readonly ResearchFeedbackCategory[];
}

function validateContent(content: ResearchCaseContent): ResearchCaseContent {
  if (!content || typeof content !== "object") {
    throw new ResearchPolicyViolation(
      "Case content is required",
      "invalid_case",
    );
  }
  assertNonEmptyString(content.observation, "content.observation");
  if (
    !Array.isArray(content.evidence) ||
    content.evidence.some(
      (item) => typeof item !== "string" || item.trim().length === 0,
    )
  ) {
    throw new ResearchPolicyViolation(
      "content.evidence must contain only non-empty strings",
      "invalid_case",
    );
  }
  if (content.context !== undefined) {
    assertNonEmptyString(content.context, "content.context");
  }
  return {
    observation: content.observation,
    evidence: [...content.evidence],
    ...(content.context === undefined ? {} : { context: content.context }),
  };
}

function validateBase(input: SyntheticCaseInput | HumanCaseInput) {
  assertNoIngestionMarkers(input);
  assertNonEmptyString(input.caseId, "caseId");
  assertNonEmptyString(input.createdAt, "createdAt");
  if (!Number.isFinite(Date.parse(input.createdAt))) {
    throw new ResearchPolicyViolation(
      "createdAt must be an ISO date",
      "invalid_case",
    );
  }
  return {
    schemaVersion: 1 as const,
    caseId: input.caseId,
    feedbackCategories: validateCategories(input.feedbackCategories),
    content: validateContent(input.content),
    createdAt: new Date(input.createdAt).toISOString(),
  };
}

export function createSyntheticCase(
  input: SyntheticCaseInput,
): SyntheticObservationCase {
  if (input.provenance !== "synthetic") {
    throw new ResearchPolicyViolation(
      "Synthetic cases must declare synthetic provenance",
      "invalid_case",
    );
  }
  return { ...validateBase(input), provenance: "synthetic" };
}

export function createHumanCase(input: HumanCaseInput): HumanObservationCase {
  if (
    input.provenance !== "consented_human_submission" ||
    input.submissionProvenance !== "explicit_case_submission"
  ) {
    throw new ResearchPolicyViolation(
      "Human cases must use explicit_case_submission provenance",
      "consent_required",
    );
  }
  if (
    !input.consent ||
    input.consent.explicitConsent !== true ||
    input.consent.scope !== "explicit_case_submission"
  ) {
    throw new ResearchPolicyViolation(
      "Explicit consent is required before a human case can be queued",
      "consent_required",
    );
  }
  assertNonEmptyString(input.consent.receiptId, "consent.receiptId");
  assertNonEmptyString(input.consent.policyVersion, "consent.policyVersion");
  assertNonEmptyString(input.consent.consentedAt, "consent.consentedAt");
  if (!Number.isFinite(Date.parse(input.consent.consentedAt))) {
    throw new ResearchPolicyViolation(
      "consent.consentedAt must be an ISO date",
      "invalid_case",
    );
  }

  return {
    ...validateBase(input),
    provenance: "consented_human_submission",
    submissionProvenance: "explicit_case_submission",
    consent: {
      receiptId: input.consent.receiptId,
      policyVersion: input.consent.policyVersion,
      consentedAt: new Date(input.consent.consentedAt).toISOString(),
      scope: "explicit_case_submission",
      explicitConsent: true,
    },
  };
}

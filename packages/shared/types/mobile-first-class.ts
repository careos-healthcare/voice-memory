export type MobileJourneyStepId =
  | "install"
  | "onboarding"
  | "record"
  | "archive_belief"
  | "archive_changes"
  | "protect_archive"
  | "paywall"
  | "purchase"
  | "restore"
  | "return";

export type MobileJourneyStep = {
  id: MobileJourneyStepId;
  label: string;
  reachableOnMobile: boolean;
  requiresWeb: boolean;
  evidence: string[];
  blockers: string[];
};

export type MobileJourneyAudit = {
  generatedAt: string;
  steps: MobileJourneyStep[];
  completeWithoutWeb: boolean;
  failingStepIds: MobileJourneyStepId[];
};

export type ParityFeatureId =
  | "belief"
  | "evidence"
  | "timeline"
  | "trust"
  | "reputation"
  | "ownership"
  | "survival"
  | "accuracy"
  | "contradictions"
  | "activity"
  | "search"
  | "export"
  | "auth"
  | "subscription";

export type ParityStatus = "MISSING" | "PARTIAL" | "COMPLETE";

export type MobileParityFeature = {
  id: ParityFeatureId;
  label: string;
  status: ParityStatus;
  mobileSurface: string;
  notes: string[];
};

export type MobileParityReport = {
  generatedAt: string;
  features: MobileParityFeature[];
  missingCount: number;
  partialCount: number;
  completeCount: number;
  v1RequiredComplete: boolean;
  lines: string[];
};

export type IndependenceViolationKind =
  | "desktop_route"
  | "desktop_only_component"
  | "web_only_flow"
  | "browser_only_purchase"
  | "desktop_only_settings"
  | "desktop_only_auth";

export type MobileIndependenceViolation = {
  kind: IndependenceViolationKind;
  detail: string;
  file?: string;
};

export type MobileIndependenceAudit = {
  generatedAt: string;
  independent: boolean;
  violations: MobileIndependenceViolation[];
};

export type PaywallAuditCheckId =
  | "revenuecat"
  | "restore_purchases"
  | "subscription_state"
  | "entitlement_refresh"
  | "offline_purchase_recovery";

export type PaywallAuditCheck = {
  id: PaywallAuditCheckId;
  label: string;
  passed: boolean;
  note: string;
};

export type MobilePaywallAudit = {
  generatedAt: string;
  checks: PaywallAuditCheck[];
  nativeStoreReady: boolean;
  purchaseRecoveryComplete: boolean;
};

export type ArchiveReviewQuestionId =
  | "understand_archive"
  | "see_belief"
  | "see_trust"
  | "see_change"
  | "protect_archive"
  | "subscribe"
  | "restore";

export type ArchiveReviewAnswer = {
  id: ArchiveReviewQuestionId;
  question: string;
  answerableOnMobile: boolean;
  evidence: string[];
};

export type MobileArchiveReview = {
  generatedAt: string;
  questions: ArchiveReviewAnswer[];
  allFromMobile: boolean;
};

export type MobileDistributionPillar = {
  label: string;
  status: "UNKNOWN" | "FAILING" | "PASSING";
  passing: number;
  total: number;
  summary: string;
};

export type FounderPlatformVerdict = "COMPANION_APP" | "PRIMARY_PLATFORM";

export type MobileFirstClassReport = {
  generatedAt: string;
  journey: MobileJourneyAudit;
  parity: MobileParityReport;
  independence: MobileIndependenceAudit;
  paywall: MobilePaywallAudit;
  archiveReview: MobileArchiveReview;
  productReadiness: MobileDistributionPillar;
  storeReadiness: MobileDistributionPillar;
  distributionReadiness: MobileDistributionPillar;
  verdict: FounderPlatformVerdict;
  verdictReasons: string[];
  validationFailures: string[];
};

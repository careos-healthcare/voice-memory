export type PilotAccessStatus = "approved" | "invited" | "observing" | "declined";

export type PilotFounderLabel =
  | "highly_attached"
  | "trust_sensitive"
  | "likely_early_supporter"
  | "not_ready";

export type PilotInterestKind =
  | "viewed_pilot_page"
  | "opened_pricing_explanation"
  | "asked_about_payment"
  | "backup_before_interest"
  | "export_before_interest"
  | "revisit_after_pilot"
  | "trust_drop_after_pilot"
  | "abandon_after_pilot";

export interface PilotInterestEvent {
  id: string;
  kind: PilotInterestKind;
  at: string;
  meta?: Record<string, string>;
}

export interface PilotFounderLabelRecord {
  id: string;
  participantId: string;
  label: PilotFounderLabel;
  note?: string;
  createdAt: string;
}

export interface PilotInterestReport {
  generatedAt: string;
  hasData: boolean;
  events: PilotInterestEvent[];
  founderLabels: PilotFounderLabelRecord[];
  summary: {
    pageViews: number;
    pricingOpens: number;
    paymentQuestions: number;
    revisitAfterPilot: number;
    trustDrops: number;
    abandons: number;
  };
}

export interface PilotFounderNote {
  id: string;
  participantId: string;
  attachmentStrength?: string;
  trustSensitivity?: string;
  archiveMaturity?: string;
  continuityUsage?: string;
  revisitDepth?: string;
  text?: string;
  updatedAt: string;
}

export interface PilotAccessRecord {
  participantId: string;
  label?: string;
  status: PilotAccessStatus;
  founderNotes: PilotFounderNote | null;
  updatedAt: string;
}

export interface PilotAccessReport {
  generatedAt: string;
  roster: PilotAccessRecord[];
  approvedCount: number;
  invitedCount: number;
  observingCount: number;
  declinedCount: number;
  capacityRemaining: number;
}

export type PilotSuppressionReason =
  | "legitimacy_weak"
  | "revisit_fatigue"
  | "trust_risk_elevated"
  | "archive_value_ignored"
  | "attachment_weak"
  | "capacity_full";

export interface PilotRestraintReport {
  generatedAt: string;
  allowed: boolean;
  suppressionReasons: PilotSuppressionReason[];
}

export interface PilotCandidateRow {
  id: string;
  participantId: string;
  label: string;
  detail: string;
  score: number;
}

export interface PilotReviewReport {
  generatedAt: string;
  hasData: boolean;
  strongestAttachment: PilotCandidateRow[];
  safestPilotCandidates: PilotCandidateRow[];
  trustRiskUsers: PilotCandidateRow[];
  archiveMaturity: number;
  revisitDepth: number;
  willingnessEvolution: Array<{ at: string; label: string; detail: string }>;
  monetizationLegitimacy: number;
  trustImpactAfterExposure: {
    before: number | null;
    after: number | null;
  };
  interest: PilotInterestReport;
  access: PilotAccessReport;
  restraint: PilotRestraintReport;
}

export interface PilotReadinessCheck {
  id: string;
  label: string;
  ok: boolean;
  detail: string;
}

export interface PilotReadinessReport {
  generatedAt: string;
  ready: boolean;
  observeMessage: string | null;
  paymentReadinessConfidence: number;
  checks: PilotReadinessCheck[];
}

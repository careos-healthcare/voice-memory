export type PremiumState =
  | "free"
  | "considering"
  | "interested"
  | "willing_to_pay_observed";

export type PremiumSurface = "account" | "archive" | "restore" | "export";

export type ArchiveValueMomentKind =
  | "encrypted_backup"
  | "export_usage"
  | "restore_usage"
  | "oldest_revisited"
  | "reopen_chain"
  | "would_miss_archive"
  | "return_after_absence"
  | "restore_after_reinstall";

export interface ArchiveValueMoment {
  id: string;
  kind: ArchiveValueMomentKind;
  label: string;
  detail: string;
  strength: number;
  at?: string;
}

export interface ArchiveValueLine {
  id: string;
  text: string;
  momentKind: ArchiveValueMomentKind;
  surface: PremiumSurface;
}

export interface ArchiveValueReport {
  generatedAt: string;
  hasData: boolean;
  moments: ArchiveValueMoment[];
  strongestMoment: ArchiveValueMoment | null;
  suggestedLine: ArchiveValueLine | null;
}

export type MonetizationSuppressionReason =
  | "emotional_moment_active"
  | "revisit_payoff_active"
  | "premium_recently_ignored"
  | "trust_risk_elevated"
  | "legitimacy_weak"
  | "session_cap_reached"
  | "surface_not_allowed"
  | "insufficient_attachment";

export interface MonetizationRestraintReport {
  generatedAt: string;
  allowed: boolean;
  suppressionReasons: MonetizationSuppressionReason[];
}

export interface MonetizationObservationEvent {
  id: string;
  kind:
    | "premium_line_seen"
    | "backup_after_premium"
    | "export_after_premium"
    | "revisit_after_premium"
    | "trust_drop_after_premium"
    | "session_abandon_after_premium"
    | "legitimacy_snapshot";
  at: string;
  surface?: PremiumSurface;
  line?: string;
  meta?: Record<string, string>;
}

export interface MonetizationObservationReport {
  generatedAt: string;
  hasData: boolean;
  premiumLinesSeen: number;
  backupAfterPremium: number;
  exportAfterPremium: number;
  revisitAfterPremium: number;
  trustDropAfterPremium: number;
  sessionAbandonAfterPremium: number;
  legitimacyBeforeExposure: number | null;
  legitimacyAfterExposure: number | null;
  events: MonetizationObservationEvent[];
}

export interface ArchiveValueReviewReport {
  generatedAt: string;
  hasData: boolean;
  attachmentSignals: Array<{ id: string; label: string; detail: string; strength: number }>;
  safestMoments: ArchiveValueMoment[];
  trustRiskMoments: ArchiveValueMoment[];
  suppressionReasons: MonetizationSuppressionReason[];
  archiveProtectionInterest: number;
  premiumState: PremiumState;
  wtpEvolution: Array<{ at: string; label: string; detail: string }>;
  legitimacyBeforeExposure: number | null;
  legitimacyAfterExposure: number | null;
  observation: MonetizationObservationReport;
  restraint: MonetizationRestraintReport;
}

export interface PremiumStateRecord {
  state: PremiumState;
  updatedAt: string;
  source: "behavior" | "founder";
}

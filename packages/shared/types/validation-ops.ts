import type { FounderReviewRankedItem } from "@/types/validation-phase";
import type { StudyParticipantRecord } from "@/types/retention-observation";

export type WillingnessSignalKind =
  | "asked_about_pricing"
  | "exported_archive"
  | "enabled_backup"
  | "revisited_after_absence"
  | "returned_after_failed_sync"
  | "copied_or_shared_moment"
  | "would_miss_archive";

export type FounderWillingnessLabel = "would_pay" | "maybe" | "unlikely";

export interface WillingnessBehaviorSignal {
  id: string;
  kind: WillingnessSignalKind;
  label: string;
  detail: string;
  at: string;
  strength: number;
}

export interface WillingnessLabelRecord {
  id: string;
  participantId: string;
  label: FounderWillingnessLabel;
  note?: string;
  createdAt: string;
}

export interface WillingnessSignalsReport {
  generatedAt: string;
  hasData: boolean;
  behavioral: WillingnessBehaviorSignal[];
  founderLabels: WillingnessLabelRecord[];
  summary: {
    wouldPay: number;
    maybe: number;
    unlikely: number;
    behavioralCount: number;
  };
}

export type ArchiveAttachmentKind =
  | "oldest_revisited"
  | "durable_landmark"
  | "reopen_chain"
  | "copied_callback_reopened"
  | "reflection_revisited_months_later"
  | "export_before_deletion"
  | "restore_after_reinstall";

export interface ArchiveAttachmentSignal {
  id: string;
  kind: ArchiveAttachmentKind;
  label: string;
  detail: string;
  entryId?: string;
  strength: number;
}

export interface ArchiveAttachmentReport {
  generatedAt: string;
  hasData: boolean;
  signals: ArchiveAttachmentSignal[];
  attachmentScore: number;
  irreplaceable: boolean;
}

export type RolloutStage =
  | "prototype"
  | "emotional_validation"
  | "attachment_validation"
  | "permanence_validation"
  | "monetization_ready";

export interface RolloutGateCheck {
  id: string;
  label: string;
  ok: boolean;
  detail: string;
}

export interface RolloutGatesReport {
  generatedAt: string;
  currentStage: RolloutStage;
  recommendedStage: RolloutStage;
  observeLonger: boolean;
  observeMessage: string | null;
  checks: RolloutGateCheck[];
  stageProgress: Record<RolloutStage, boolean>;
}

export type FounderWarningKind =
  | "callback_repetition"
  | "revisit_fatigue"
  | "emotional_overclaim"
  | "explaining_too_much"
  | "archive_overdesigned"
  | "emotional_specificity_loss"
  | "archive_convergence"
  | "archive_emotionally_crowded"
  | "meaningfulness_inflation"
  | "silence_over_resurfacing"
  | "retention_novelty_drop"
  | "performative_sharing"
  | "export_before_churn";

export interface FounderWarning {
  id: string;
  kind: FounderWarningKind;
  label: string;
  detail: string;
  severity: "watch" | "concern";
}

export interface FounderWarningsReport {
  generatedAt: string;
  warnings: FounderWarning[];
}

import type { MonetizationObservationReport } from "@/types/monetization-validation";

export interface ValidationOpsMetricRow {
  id: string;
  label: string;
  value: string;
  detail?: string;
}

export interface ValidationOpsReport {
  generatedAt: string;
  hasData: boolean;
  activeTesters: StudyParticipantRecord[];
  retention: {
    d1: ValidationOpsMetricRow;
    d7: ValidationOpsMetricRow;
    d30: ValidationOpsMetricRow;
  };
  revisit: ValidationOpsMetricRow[];
  willingness: WillingnessSignalsReport;
  attachment: ArchiveAttachmentReport;
  rollout: RolloutGatesReport;
  warnings: FounderWarningsReport;
  rememberedLater: FounderReviewRankedItem[];
  trustFailures: FounderReviewRankedItem[];
  syncFailures: FounderReviewRankedItem[];
  archiveOps: ValidationOpsMetricRow[];
  emotionalLegitimacyTrend: ValidationOpsMetricRow[];
  monetizationObservation: MonetizationObservationReport;
  premiumState: string;
}

export interface FounderUserNote {
  id: string;
  participantId: string;
  text: string;
  createdAt: string;
}

export interface FounderFollowUpReminder {
  id: string;
  participantId: string;
  dueDay: string;
  note: string;
  completed: boolean;
  createdAt: string;
}

export interface UserReviewSection {
  title: string;
  rows: FounderReviewRankedItem[];
  empty: string;
}

export interface UserReviewReport {
  generatedAt: string;
  participant: StudyParticipantRecord;
  sections: {
    strongestCallbacks: UserReviewSection;
    ignoredCallbacks: UserReviewSection;
    revisitBehavior: UserReviewSection;
    reflectionContinuation: UserReviewSection;
    trustIncidents: UserReviewSection;
    emotionalLegitimacy: UserReviewSection;
    attachmentSignals: UserReviewSection;
    willingnessSignals: UserReviewSection;
    feltRemembered: UserReviewSection;
    feltGeneric: UserReviewSection;
  };
  founderNotes: FounderUserNote[];
  followUpReminders: FounderFollowUpReminder[];
}

export interface AnonymizedUserReviewExport {
  schemaVersion: 1;
  exportedAt: string;
  participantLabel: string;
  studyDayCount: number;
  sections: UserReviewReport["sections"];
  willingnessSummary: WillingnessSignalsReport["summary"];
  attachmentScore: number;
  rolloutStage: RolloutStage;
}

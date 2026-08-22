export type MagicEvidenceKind =
  | "repeated_phrase"
  | "repeated_concern"
  | "mood_shift"
  | "time_gap";

export type MagicMomentEventName =
  | "magic_candidate_created"
  | "magic_candidate_shown"
  | "magic_candidate_opened"
  | "magic_candidate_saved"
  | "magic_candidate_shared"
  | "magic_followup_recorded"
  | "magic_return_after_callback";

export type MagicEngagementKind =
  | "opened"
  | "saved"
  | "shared"
  | "followup_recorded"
  | "return_after_callback";

export interface MagicCandidateQualification {
  noteId: string;
  entryId?: string;
  pastEntryId?: string;
  surface?: string;
  evidence: MagicEvidenceKind[];
  classification: string;
  qualityTotal: number;
}

export interface MagicMomentMetrics {
  timeUntilFirstMeaningfulCallbackMs: number | null;
  callbackOpenRate: number;
  candidatesCreated: number;
  candidatesShown: number;
  candidatesOpened: number;
  firstMagicConfirmedAt: string | null;
  firstMagicEngagement: MagicEngagementKind | null;
}

export interface MagicMomentEventRow {
  name: MagicMomentEventName;
  at: string;
  noteId?: string;
  surface?: string;
  evidence?: string;
  engagement?: string;
}

export interface MagicMomentDebugReport {
  generatedAt: string;
  hasData: boolean;
  metrics: MagicMomentMetrics;
  recentEvents: MagicMomentEventRow[];
  qualifications: MagicCandidateQualification[];
}

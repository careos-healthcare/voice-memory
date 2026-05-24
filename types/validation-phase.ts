export type TesterFeedbackKind =
  | "felt_wrong"
  | "really_landed"
  | "revisited_because"
  | "forgot_i_sounded";

export interface TesterFeedbackRecord {
  id: string;
  kind: TesterFeedbackKind;
  text: string;
  entryId?: string;
  noteId?: string;
  createdAt: string;
}

export type IncidentKind =
  | "failed_sync"
  | "failed_restore"
  | "missing_audio"
  | "corrupted_export"
  | "quota_issue"
  | "indexeddb_failure"
  | "replay_mismatch";

export interface IncidentRecord {
  id: string;
  kind: IncidentKind;
  detail: string;
  detectedAt: string;
  resolved?: boolean;
  meta?: Record<string, string>;
}

export interface IncidentBundle {
  exportedAt: string;
  incidentCount: number;
  openCount: number;
  incidents: IncidentRecord[];
  liveScan: IncidentRecord[];
}

export interface WeeklyRetentionSnapshot {
  weekStart: string;
  generatedAt: string;
  studyDayCount: number;
  returnDayCount: number;
  reflectionCount: number;
  oldEntryRevisits: number;
  revisitToReflection: number;
  followupsStarted: number;
  followupsCompleted: number;
  bookmarks: number;
  copiedMoments: number;
  day7Returns: number;
}

export interface CallbackSurvivalSummaryRow {
  id: string;
  text: string;
  survivalScore: number;
  residueScore: number;
  shown: number;
  remembered24h: boolean;
  remembered72h: boolean;
  pruningAction?: string;
}

export interface RevisitConversionSummary {
  memoryNoteClicks: number;
  oldEntryOpens: number;
  revisits: number;
  followupsStarted: number;
  followupsCompleted: number;
  revisitToReflection: number;
  conversionRate: string;
}

export interface EmotionalResidueSummaryRow {
  id: string;
  source: "manual_note" | "callback";
  text: string;
  feltRemembered?: boolean;
  feltGeneric?: boolean;
  wouldPay?: string;
  at: string;
}

export interface ObservationSummariesExport {
  exportedAt: string;
  weeklySnapshots: WeeklyRetentionSnapshot[];
  callbackSurvival: CallbackSurvivalSummaryRow[];
  revisitConversion: RevisitConversionSummary;
  emotionalResidue: EmotionalResidueSummaryRow[];
}

export interface FounderReviewRankedItem {
  id: string;
  label: string;
  detail?: string;
  score?: number;
}

export interface FounderReviewReport {
  generatedAt: string;
  strongestCallbacks: FounderReviewRankedItem[];
  deadCallbacks: FounderReviewRankedItem[];
  strongestRevisitMoments: FounderReviewRankedItem[];
  emotionalResidueLeaders: FounderReviewRankedItem[];
  trustFailures: FounderReviewRankedItem[];
  syncHealthSummary: string[];
  monetizationHeadline: string;
  monetizationVerdict: string;
  retentionTrend: WeeklyRetentionSnapshot[];
  openIncidents: number;
  testerFeedbackCount: number;
}

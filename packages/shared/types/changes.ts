export type ChangeKind =
  | "pattern_started"
  | "pattern_intensified"
  | "pattern_faded"
  | "pattern_disappeared"
  | "pattern_returned"
  | "more_direct"
  | "less_hedged"
  | "became_calm"
  | "more_future_oriented"
  | "phrase_stopped"
  | "topic_less_charged";

export type ChangeSubjectType = "theme" | "entity" | "phrase" | "language" | "topic";

export type ChangeConfidenceLabel = "strong" | "moderate" | "weak";

export type ChangeScope = "archive" | "weekly" | "monthly" | "timeline";

export interface ChangeEvidence {
  entryId: string;
  dateKey: string;
  dateLabel: string;
  snippet: string;
  intensity?: number;
  mood?: string;
}

export interface ChangeDateRange {
  startKey: string;
  endKey: string;
  label: string;
}

export interface LongitudinalChange {
  id: string;
  kind: ChangeKind;
  summary: string;
  subject: string;
  subjectType: ChangeSubjectType;
  confidence: number;
  confidenceLabel: ChangeConfidenceLabel;
  dateRange: ChangeDateRange;
  beforeEvidence: ChangeEvidence[];
  afterEvidence: ChangeEvidence[];
  entryIds: string[];
}

export interface ChangeDetectionReport {
  changes: LongitudinalChange[];
  hasData: boolean;
  scope: ChangeScope;
  generatedAt: string;
}

export interface ChangeCandidate extends LongitudinalChange {
  accepted: boolean;
  rejectionReason?: string;
  scoreBreakdown: Record<string, number>;
  warnings: string[];
}

export interface ChangeDebugReport {
  candidates: ChangeCandidate[];
  accepted: ChangeCandidate[];
  rejected: ChangeCandidate[];
  averageConfidence: number;
  generatedAt: string;
}

export const CHANGE_KIND_LABELS: Record<ChangeKind, string> = {
  pattern_started: "Pattern started",
  pattern_intensified: "Pattern intensified",
  pattern_faded: "Pattern faded",
  pattern_disappeared: "Pattern disappeared",
  pattern_returned: "Pattern returned",
  more_direct: "More direct language",
  less_hedged: "Less hedging",
  became_calm: "Became calmer",
  more_future_oriented: "More future-oriented",
  phrase_stopped: "Phrase stopped",
  topic_less_charged: "Topic less charged",
};

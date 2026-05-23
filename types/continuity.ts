export type ContinuitySubjectType =
  | "theme"
  | "entity"
  | "phrase"
  | "emotion"
  | "identity"
  | "narrative";

export type ContinuitySurfaceLabel =
  | "changed_over_time"
  | "disappeared"
  | "more_intense"
  | "calmer"
  | "reappeared"
  | "emerged";

export type ContinuityItemKind =
  | "timeline_phase"
  | "change_moment"
  | "before_after"
  | "period_summary"
  | "narrative_arc"
  | "identity_drift";

export type NarrativeArcKind =
  | "unresolved_loop"
  | "recurring_cycle"
  | "completed_transition"
  | "recovery_pattern";

export type TimelinePhaseKind =
  | "first_appearance"
  | "peak"
  | "decline"
  | "absence"
  | "reappearance";

export interface ContinuityEvidence {
  entryId: string;
  dateKey: string;
  dateLabel: string;
  phrase: string;
  mood?: string;
  intensity?: number;
}

export interface TimelinePhase {
  kind: TimelinePhaseKind;
  startKey: string;
  endKey: string;
  startLabel: string;
  endLabel: string;
  avgIntensity?: number;
  note: string;
}

export interface ContinuityItem {
  id: string;
  kind: ContinuityItemKind;
  surface: ContinuitySurfaceLabel;
  title: string;
  detail: string;
  subject: string;
  subjectType: ContinuitySubjectType;
  confidence: number;
  entryIds: string[];
  evidence: ContinuityEvidence[];
  phases?: TimelinePhase[];
}

export interface NarrativeArc {
  id: string;
  kind: NarrativeArcKind;
  title: string;
  detail: string;
  entryIds: string[];
  confidence: number;
}

export interface PeriodSummary {
  id: string;
  period: "month" | "quarter";
  periodLabel: string;
  title: string;
  lines: string[];
  entryIds: string[];
}

export interface IdentityDriftInsight {
  id: string;
  title: string;
  detail: string;
  direction:
    | "more_certain"
    | "more_uncertain"
    | "more_direct"
    | "more_hopeful"
    | "more_flat";
  entryIds: string[];
  confidence: number;
}

export type ContinuityScope = "archive" | "weekly" | "entry" | "timeline";

export interface ContinuityReport {
  items: ContinuityItem[];
  changeMoments: ContinuityItem[];
  beforeAfter: ContinuityItem[];
  narrativeArcs: NarrativeArc[];
  periodSummaries: PeriodSummary[];
  identityDrift: IdentityDriftInsight[];
  hasData: boolean;
  generatedAt: string;
  scope: ContinuityScope;
}

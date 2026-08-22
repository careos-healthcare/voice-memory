import type { PersonalTheoryStatus } from "@/types/personal-theory";
import type { TheoryEvidenceQuote, TheorySource } from "@/types/theory";

export type ArchiveBeliefEventName =
  | "archive_belief_viewed"
  | "archive_belief_expanded"
  | "belief_change_viewed"
  | "belief_timeline_viewed";

export interface ArchiveBeliefEvent {
  name: ArchiveBeliefEventName;
  at: string;
  theoryId?: string;
  surface?: string;
}

export interface ArchiveBeliefChangeLine {
  id: string;
  text: string;
}

export interface ArchiveBeliefEvidence {
  supportingQuotes: TheoryEvidenceQuote[];
  contradictingQuotes: TheoryEvidenceQuote[];
  lifeAreas: string[];
  costEvidenceLines: string[];
  predictionFailureLines: string[];
}

export interface ArchiveBeliefView {
  theoryId: string;
  source: TheorySource;
  belief: string;
  confidence: number;
  status: PersonalTheoryStatus;
  statusLabel: string;
  statusExplanation: string;
  changeLines: ArchiveBeliefChangeLine[];
  evidence: ArchiveBeliefEvidence;
}

export interface ArchiveBeliefAdoptionReport {
  title: string;
  generatedAt: string;
  beliefCardViewedCount: number;
  beliefExpandedCount: number;
  beliefChangeViewedCount: number;
  beliefTimelineViewedCount: number;
  beliefCardOpenRate: number | null;
  evidenceOpenRate: number | null;
  returnAfterBeliefChangeRate: number | null;
  timelineViewRate: number | null;
  discoverOpenCount: number;
  productFramingUnderstandingPct: number | null;
  productFramingInsightsPct: number | null;
  productFramingSampleSize: number;
  validationChecklist: string[];
  lines: string[];
}

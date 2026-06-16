/** GPT-5 synthesis V2 — narrative layer on deterministic archive engines. */

export type ArchiveSynthesisType =
  | "monthly"
  | "milestone"
  | "deep_dive"
  | "historian";

export interface ArchiveSynthesisEvidenceRef {
  entryId: string;
  excerpt?: string;
  role?: "support" | "counter" | "context";
}

export interface ArchiveSynthesisConclusion {
  id: string;
  statement: string;
  confidencePercent: number;
  uncertaintyNote: string;
  evidence: ArchiveSynthesisEvidenceRef[];
}

export interface ArchiveSynthesisTheoryRef {
  candidateId: string;
  statement: string;
  confidencePercent: number;
  evidenceCount: number;
  counterEvidenceCount: number;
  rankScore: number;
}

export interface ArchiveSynthesisDeepDiveContext {
  beliefStatement: string;
  confidencePercent: number;
  whySummaryLines: string[];
  excerptEntryIds: string[];
  timelineLabels: string[];
}

export interface ArchiveSynthesisPack {
  packVersion: 1 | 2;
  monthKey: string;
  eligibleCount: number;
  /** Unified primary from TheoryRankingEngine (V2). */
  primaryTheory: ArchiveSynthesisTheoryRef | null;
  /** Next-ranked theories (V2). */
  secondaryTheories: ArchiveSynthesisTheoryRef[];
  theory: {
    statement: string;
    confidencePercent: number;
    evidenceCount: number;
    counterEvidenceCount: number;
  } | null;
  lifecycle: {
    current: {
      statement: string;
      status: string;
      firstSeen?: string;
      lastSeen?: string;
    } | null;
    retired: Array<{ statement: string; status: string; lastSeen?: string }>;
  };
  changeFeed: {
    hasBaseline: boolean;
    reviewedAt?: string;
    newReflectionCount: number;
    beliefsStrengthened: Array<{
      statement: string;
      confidenceBefore: number;
      confidenceNow: number;
    }>;
    beliefsWeakened: Array<{
      statement: string;
      confidenceBefore: number;
      confidenceNow: number;
    }>;
    contradictionsAppeared: Array<{ youSay: string; but: string }>;
    contradictionsResolved: Array<{ youSay: string; but: string }>;
    themesIncreasing: Array<{ label: string; mentionsNow: number }>;
    themesDecreasing: Array<{ label: string; mentionsNow: number }>;
  };
  contradictions: Array<{
    id: string;
    youSay: string;
    but: string;
    confidenceScore: number;
    entryIds: string[];
  }>;
  blindSpots: Array<{
    id: string;
    headline: string;
    observation: string;
    entryIds: string[];
  }>;
  surprises: Array<{
    id: string;
    observation: string;
    evidenceEntryIds: string[];
    confidenceScore: number;
  }>;
  evidenceTrails: {
    forExcerpts: Array<{ entryId: string; quote: string }>;
    againstExcerpts: Array<{ entryId: string; quote: string }>;
  };
  reflectionIndex: Array<{
    id: string;
    createdAt: string;
    mood: string;
    emotionalIntensity: number;
    recurringThemes: string[];
    concreteObservation: string;
    repeatedSignal: string;
    tensionOrContradiction?: string;
  }>;
  milestonesReached: number[];
  /** Optional — deep_dive synthesis only. */
  deepDiveContext?: ArchiveSynthesisDeepDiveContext;
}

export interface ArchiveMonthlyReview {
  reviewVersion: 2;
  monthKey: string;
  archiveHash: string;
  eligibleCount: number;
  generatedAt: string;
  model: string;
  whatChanged: ArchiveSynthesisConclusion[];
  emergingTheories: ArchiveSynthesisConclusion[];
  fadingTheories: ArchiveSynthesisConclusion[];
  surprises: ArchiveSynthesisConclusion[];
  biggestSurprise: ArchiveSynthesisConclusion | null;
  strongestContradiction: ArchiveSynthesisConclusion | null;
  evidenceFor: ArchiveSynthesisConclusion[];
  evidenceAgainst: ArchiveSynthesisConclusion[];
}

export interface ArchiveMilestoneReview {
  reviewVersion: 2;
  milestoneThreshold: number;
  eligibleCount: number;
  archiveHash: string;
  generatedAt: string;
  model: string;
  headline: string;
  narrative: string;
  primaryTheorySummary: ArchiveSynthesisConclusion;
  changeHighlights: ArchiveSynthesisConclusion[];
  uncertaintyNote: string;
}

export interface ArchiveDeepDiveNarrative {
  reviewVersion: 2;
  beliefStatement: string;
  archiveHash: string;
  generatedAt: string;
  model: string;
  narrativeExplanation: string;
  evidenceSynthesis: ArchiveSynthesisConclusion[];
  beliefEvolutionSummary: ArchiveSynthesisConclusion;
  uncertaintyNote: string;
}

export interface ArchiveHistorianReport {
  reviewVersion: 2;
  monthKey: string;
  archiveHash: string;
  eligibleCount: number;
  generatedAt: string;
  model: string;
  title: string;
  timeline: ArchiveSynthesisConclusion[];
  uncertaintyNote: string;
}

export interface ArchiveSynthesisRequestBody {
  synthesisType?: ArchiveSynthesisType;
  monthKey: string;
  userId: string;
  pack: ArchiveSynthesisPack;
  /** Required for milestone synthesis (50 | 100 | 200 | 500). */
  milestoneThreshold?: number;
}

export type ArchiveSynthesisResult =
  | { synthesisType: "monthly"; review: ArchiveMonthlyReview; cached: boolean }
  | {
      synthesisType: "milestone";
      review: ArchiveMilestoneReview;
      cached: boolean;
    }
  | {
      synthesisType: "deep_dive";
      review: ArchiveDeepDiveNarrative;
      cached: boolean;
    }
  | {
      synthesisType: "historian";
      review: ArchiveHistorianReport;
      cached: boolean;
    };

/** @deprecated Use ArchiveSynthesisResult */
export interface ArchiveSynthesisResponseBody {
  review: ArchiveMonthlyReview;
  cached: boolean;
}

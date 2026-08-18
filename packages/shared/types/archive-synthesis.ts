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

/** V1 belief anchor from Discover/lifecycle engines. */
export interface ArchiveSynthesisBeliefRef {
  statement: string;
  confidencePercent: number;
  evidenceCount: number;
}

/** Theory-ranking ref when theory tracking is enabled. */
export interface ArchiveSynthesisTheoryRef {
  candidateId: string;
  statement: string;
  confidencePercent: number;
  evidenceCount: number;
  counterEvidenceCount: number;
  rankScore: number;
}

export interface ArchiveSynthesisTheorySnapshot {
  statement: string;
  confidencePercent: number;
  evidenceCount: number;
  counterEvidenceCount: number;
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
  /** V1 primary belief from discover/lifecycle engines. */
  primaryBelief?: ArchiveSynthesisBeliefRef | null;
  /**
   * Ranked theories from the on-device theory engine — populated when theory
   * tracking is enabled (`VOICEMEMORY_ENABLE_THEORY_TRACKING`). Fed to monthly /
   * milestone synthesis prompts; stripped server-side when the flag is off.
   */
  primaryTheory?: ArchiveSynthesisTheoryRef | null;
  secondaryTheories?: ArchiveSynthesisTheoryRef[];
  /** Compact hero-theory snapshot (same statement as primaryTheory when ranked). */
  theory?: ArchiveSynthesisTheorySnapshot | null;
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
  /** Theories gaining support — cite changeFeed + pack.primaryTheory when present. */
  emergingTheories: ArchiveSynthesisConclusion[];
  /** Theories losing support — cite changeFeed when present. */
  fadingTheories: ArchiveSynthesisConclusion[];
  surprises: ArchiveSynthesisConclusion[];
  biggestSurprise: ArchiveSynthesisConclusion | null;
  strongestContradiction: ArchiveSynthesisConclusion | null;
  /** Supporting excerpts for pack.primaryTheory (empty when no theory in pack). */
  evidenceFor: ArchiveSynthesisConclusion[];
  /** Counter excerpts for pack.primaryTheory (empty when no theory in pack). */
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
  /** Evidence-backed summary of pack.primaryTheory when theory tracking is on. */
  primaryTheorySummary: ArchiveSynthesisConclusion | null;
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

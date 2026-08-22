import type { InsightScorecard } from "@/types/insight-scorecard";

export type TheorySource = "blind_spot" | "pattern" | "prediction" | "emerging";

export type TheoryStatus =
  | "active"
  | "strengthening"
  | "weakening"
  | "resolved"
  | "retired";

export type TheoryFeedbackReaction =
  | "feels_true"
  | "partly_true"
  | "not_true"
  | "too_obvious"
  | "surprising";

export interface TheoryEvidenceQuote {
  entryId: string;
  dateLabel: string;
  quote: string;
  audioId?: string;
  startTimestampMs?: number;
  endTimestampMs?: number;
  chunkId?: string;
}

export interface Theory {
  id: string;
  statement: string;
  confidence: number;
  previousConfidence?: number;
  confidenceDelta: number;
  supportingEvidenceCount: number;
  contradictingEvidenceCount: number;
  createdAt: string;
  updatedAt: string;
  status: TheoryStatus;
  resolutionNote?: string;
  supportingEvidence: TheoryEvidenceQuote[];
  contradictingEvidence: TheoryEvidenceQuote[];
  whatChanged: string[];
  source: TheorySource;
  rootBeliefHypothesis?: string;
  scorecard?: InsightScorecard;
}

export interface TheoryTrackerReport {
  generatedAt: string;
  active: Theory[];
  strengthening: Theory[];
  weakening: Theory[];
  resolved: Theory[];
  retired: Theory[];
  all: Theory[];
}

export interface TheoryResolutionFeedReport {
  generatedAt: string;
  resolved: Theory[];
  retired: Theory[];
  total: number;
}

export interface TheoryFeedbackRecord {
  id: string;
  theoryId: string;
  reaction: TheoryFeedbackReaction;
  at: string;
  statement: string;
  source: TheorySource;
  confidence: number;
}

export interface TheorySnapshotRecord {
  theoryId: string;
  confidence: number;
  contradictingCount?: number;
  updatedAt: string;
}

export type TheoryEventName =
  | "theory_viewed"
  | "theory_expanded"
  | "theory_revisited"
  | "theory_feedback_submitted"
  | "discover_opened"
  | "theory_change_clicked"
  | "theory_change_expanded";

export type TheoryChangeCategory = "strengthened" | "weakened" | "new" | "resolved";

export interface TheoryChangeItem {
  theoryId: string;
  statement: string;
  confidence: number;
  confidenceDelta: number;
  updatedAt: string;
  shortReason: string;
  category: TheoryChangeCategory;
  source: TheorySource;
  status: TheoryStatus;
  supportingEvidenceCount: number;
  contradictingEvidenceCount: number;
}

export interface TheoryChangeFeedReport {
  generatedAt: string;
  hasBaseline: boolean;
  lastVisitAt: string | null;
  strengthened: TheoryChangeItem[];
  weakened: TheoryChangeItem[];
  new: TheoryChangeItem[];
  resolved: TheoryChangeItem[];
  totalChanges: number;
}

export interface TheoryEvidenceBaselineEntry {
  id: string;
  confidence: number;
  status: TheoryStatus;
  statement: string;
  source: TheorySource;
  supportingEntryIds: string[];
  contradictingEntryIds: string[];
  lifeAreas: string[];
  costEvidenceLines: string[];
  predictionOutcomeKey?: string;
}

export interface DiscoverVisitBaseline {
  savedAt: string;
  version: number;
  theories: TheoryEvidenceBaselineEntry[];
}

export type ProductSurfaceId =
  | "discover"
  | "blind_spot"
  | "prediction_review"
  | "emerging_pattern";

export interface SurfaceMetricRow {
  surface: ProductSurfaceId;
  label: string;
  openCount: number;
  openRate: number;
  revisitRate: number;
  surprisingRate: number;
  uncomfortablyAccurateRate: number;
  averageWowScore: number;
}

export interface SurfacePrimaryReport {
  generatedAt: string;
  sessionCount: number;
  theoryChangeOpenRate: number;
  surfaces: SurfaceMetricRow[];
  highestRevisit: ProductSurfaceId | null;
  highestSurprising: ProductSurfaceId | null;
  highestUncomfortablyAccurate: ProductSurfaceId | null;
  highestWowScore: ProductSurfaceId | null;
  primarySurfaceCandidate: ProductSurfaceId | null;
  insightLines: string[];
}

export interface TheoryEventRecord {
  id: string;
  name: TheoryEventName;
  theoryId?: string;
  at: string;
  meta?: Record<string, string>;
}

export interface TheorySourceBreakdown {
  source: TheorySource;
  count: number;
}

export type TheoryVolatilityRiskLabel = "healthy" | "quiet" | "stale" | "dead_feed_risk";

export interface TheoryVolatilityReport {
  generatedAt: string;
  riskLabel: TheoryVolatilityRiskLabel;
  riskLabelDisplay: string;
  totalTheoriesGenerated: number;
  strengthenedCount: number;
  weakenedCount: number;
  resolvedCount: number;
  retiredCount: number;
  averageDaysBetweenChanges: number | null;
  medianDaysBetweenChanges: number | null;
  daysSinceLastChange: number | null;
  discoverVisitCount: number;
  zeroMovementVisits: number;
  zeroMovementVisitRate: number;
  staleZeroMovementSessions: number;
  cumulativeMovementEvents: number;
  lastVisitHadZeroMovement: boolean;
  insightLines: string[];
}

export interface TheoryDiscoveryReport {
  generatedAt: string;
  totalTheories: number;
  resolvedCount: number;
  retiredCount: number;
  viewedTheories: number;
  expandedTheories: number;
  feedbackCounts: Record<TheoryFeedbackReaction, number>;
  revisitRate: number;
  changedTheoryRate: number;
  strongestIncreases: Array<{ theoryId: string; statement: string; delta: number }>;
  strongestDecreases: Array<{ theoryId: string; statement: string; delta: number }>;
  mostSurprising: Array<{ theoryId: string; statement: string; count: number }>;
  mostNotTrue: Array<{ theoryId: string; statement: string; count: number }>;
  sourceBreakdown: TheorySourceBreakdown[];
  volatility: TheoryVolatilityReport;
}

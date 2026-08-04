import type {
  ExplainableConclusionV4,
  HypothesisEvolution,
} from "@/types/explainability";
import type { TruthAnchor } from "@/lib/ai/truth-anchor-context";

export type DashboardTimeHorizon = "today" | "this_month" | "this_year";

export interface DashboardEvidenceInput {
  sourceEntryId: string;
  occurredAt: string;
  canonicalTranscript: string;
  audioTimestampMs?: number;
}

export interface DashboardSynthesisRequest {
  userId: string;
  horizon: DashboardTimeHorizon;
  localMetrics: Record<string, unknown>;
  evidence: DashboardEvidenceInput[];
  activeHypotheses?: HypothesisEvolution[];
  truthAnchors?: TruthAnchor[];
}

export interface DashboardSynthesisResult {
  horizon: DashboardTimeHorizon;
  identity: ExplainableConclusionV4 | null;
  goals: ExplainableConclusionV4[];
  predictions: ExplainableConclusionV4[];
}

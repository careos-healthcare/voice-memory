import type {
  ExplainableConclusionV4,
  HypothesisEvolution,
} from "@/types/explainability";
import type { TruthAnchor } from "@/lib/ai/truth-anchor-context";

export type WeeklyDeltaDimension =
  | "action_intent_ratio"
  | "emotional_velocity"
  | "habit_drift"
  | "relationship_dynamics"
  | "identity_shift";

export interface WeeklyEvidenceSource {
  sourceEntryId: string;
  week: "baseline" | "current";
  occurredAt: string;
  canonicalTranscript: string;
  audioTimestampMs?: number;
}

export interface WeeklyIntelligenceSynthesisRequest {
  userId: string;
  weekStart: string;
  weekEnd: string;
  baselineWeekCount: number;
  localDeltas: Record<string, unknown>[];
  evidence: WeeklyEvidenceSource[];
  activeHypotheses?: HypothesisEvolution[];
  truthAnchors?: TruthAnchor[];
}

export interface SynthesizedBehavioralDelta {
  dimension: WeeklyDeltaDimension;
  magnitude: number;
  nodeIds: string[];
  conclusion: ExplainableConclusionV4;
}

export interface WeeklyIntelligenceSynthesisResult {
  weekStart: string;
  weekEnd: string;
  deltas: SynthesizedBehavioralDelta[];
}

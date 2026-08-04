import type {
  ExplainableConclusionV4,
  HypothesisEvolution,
} from "@/types/explainability";

export interface RelationshipInteractionInput {
  sourceEntryId: string;
  occurredAt: string;
  interaction: string;
  emotion: string;
  emotionalValenceScore: number;
  audioTimestampMs?: number;
  canonicalTranscript: string;
}

export interface RelationshipSynthesisRequest {
  userId: string;
  personNodeId: string;
  personLabel: string;
  interactions: RelationshipInteractionInput[];
  activeHypotheses?: HypothesisEvolution[];
}

export interface RelationshipSynthesisResult {
  personNodeId: string;
  changeOverTime: ExplainableConclusionV4;
}

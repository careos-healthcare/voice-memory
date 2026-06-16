import type { TheoryEvidenceQuote, TheorySource } from "@/types/theory";

export type EvidenceMovementKind =
  | "new_supporting"
  | "new_contradicting"
  | "confidence_movement"
  | "new_life_area"
  | "new_cost_evidence"
  | "prediction_outcome";

export interface EvidenceMovement {
  kind: EvidenceMovementKind;
  theoryId: string;
  theoryStatement: string;
  source: TheorySource;
  summary: string;
  quotes: TheoryEvidenceQuote[];
  confidenceDelta?: number;
  previousConfidence?: number;
  currentConfidence?: number;
  lifeAreas?: string[];
  costEvidenceLines?: string[];
  predictionOutcomeSummary?: string;
}

export interface EvidenceFeedReport {
  generatedAt: string;
  hasBaseline: boolean;
  lastVisitAt: string | null;
  movements: EvidenceMovement[];
  totalMovements: number;
}

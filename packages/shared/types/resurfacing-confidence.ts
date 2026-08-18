export type ResurfacingConfidenceClassification =
  | "suppress"
  | "weak"
  | "plausible"
  | "strong"
  | "magic_candidate";

export interface ResurfacingConfidenceDimensions {
  repeatedPhraseScore: number;
  emotionalRecurrenceScore: number;
  temporalDistanceScore: number;
  semanticSimilarityScore: number;
  interactionReinforcementScore: number;
}

export interface ResurfacingConfidenceEvidence {
  repeatedPhrase: boolean;
  repeatedConcern: boolean;
  moodShift: boolean;
  daysSincePrior: number;
  sharedEntities: string[];
  priorInteraction: boolean;
}

export interface ResurfacingConfidenceVerdict {
  noteId: string;
  entryId?: string;
  text: string;
  totalConfidence: number;
  classification: ResurfacingConfidenceClassification;
  dimensions: ResurfacingConfidenceDimensions;
  evidence: ResurfacingConfidenceEvidence;
  evidenceSignalCount: number;
  reasons: string[];
  suppressReasons: string[];
  evidenceReason: string | null;
  falsePositiveRisks: string[];
  suppressed: boolean;
}

export interface ResurfacingConfidenceReviewRow {
  noteId: string;
  entryId: string;
  text: string;
  totalConfidence: number;
  classification: ResurfacingConfidenceClassification;
  evidenceReason: string | null;
  reasons: string[];
  suppressReasons: string[];
  falsePositiveRisks: string[];
  dimensions: ResurfacingConfidenceDimensions;
  evidence: ResurfacingConfidenceEvidence;
}

export interface ResurfacingConfidenceDebugReport {
  generatedAt: string;
  hasData: boolean;
  totalCandidates: number;
  suppressed: ResurfacingConfidenceReviewRow[];
  weak: ResurfacingConfidenceReviewRow[];
  strong: ResurfacingConfidenceReviewRow[];
  magicCandidates: ResurfacingConfidenceReviewRow[];
  topEvidenceReasons: Array<{ reason: string; count: number }>;
  falsePositiveRisks: Array<{ risk: string; count: number }>;
  interactionPenaltySamples: ResurfacingConfidenceReviewRow[];
  byClassification: Record<ResurfacingConfidenceClassification, number>;
}

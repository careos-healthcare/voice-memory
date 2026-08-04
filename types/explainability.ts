export type EvidenceRole = "support" | "counter" | "context";
export type EvidenceSourceScope = "current_transcript" | "prior_exact_snippet";
export type PriorSnippetField = "exactLanguagePattern" | "concreteObservation";

/**
 * A verbatim UTF-16-addressed slice. Current citations address the canonical
 * transcript; prior citations address only the named bounded reflection snippet,
 * never an earlier full transcript.
 */
export interface VerifiableCitation {
  sourceEntryId: string;
  exactQuote: string;
  audioTimestampMs?: number;
  /** Model confidence in this citation, normalized to 0–1. */
  confidenceScore: number;
  /** Compatibility alias retained while V1–V3 caches migrate. */
  entryId: string;
  /** Compatibility alias retained while V1–V3 caches migrate. */
  quote: string;
  /** Inclusive JavaScript string index. */
  startUtf16: number;
  /** Exclusive JavaScript string index. */
  endUtf16: number;
  role: EvidenceRole;
  sourceScope?: EvidenceSourceScope;
  sourceField?: PriorSnippetField;
}

export type TranscriptEvidenceCitation = VerifiableCitation;

export interface ConfidenceSnapshot {
  date: string;
  confidenceScore: number;
  triggeringEvidence: VerifiableCitation;
  deltaReasoning: string;
}

export interface HypothesisEvolution {
  theoryId: string;
  statement: string;
  evolutionHistory: ConfidenceSnapshot[];
}

export interface ExplainableAlternative {
  statement: string;
  reason: string;
}

export interface ConclusionProvenance {
  generatedBy: "model" | "deterministic";
  generatedAt: string;
  schemaVersion: number;
  model?: string;
  promptVersion?: string;
  sourceRevision?: string;
}

export interface ConclusionHistoryEvent {
  recordedAt: string;
  event: "created" | "revised" | "confidence_changed" | "evidence_changed";
  previousConclusionId?: string;
  note?: string;
}

export interface ExplainableConclusion {
  id: string;
  statement: string;
  confidence: number;
  confidencePercent: number;
  /** Accuracy UI alias; defaults to confidencePercent for older V4 payloads. */
  confidencePercentage?: number;
  feedbackState?: "pending" | "correct" | "incorrect" | "later";
  feedbackTimestamp?: string;
  correctionNote?: string;
  reasoning: string[];
  alternativeExplanation: ExplainableAlternative;
  uncertainty: string;
  uncertaintyNote: string;
  evidence: TranscriptEvidenceCitation[];
  alternatives: ExplainableAlternative[];
  provenance: ConclusionProvenance;
  history?: ConclusionHistoryEvent[];
  theoryId?: string;
  evolutionHistory?: ConfidenceSnapshot[];
}

/** Strict five-pillar contract for newly generated synthesis payloads. */
export interface ExplainableConclusionV4 extends ExplainableConclusion {
  confidence: number;
  reasoning: string[];
  alternativeExplanation: ExplainableAlternative;
  uncertainty: string;
  provenance: ConclusionProvenance & {
    schemaVersion: 4;
    promptVersion: "archive-explainable-v2";
  };
}

export type CanonicalTranscriptSourceMap = ReadonlyMap<string, string>;
export type PriorExactSnippetSourceMap = ReadonlyMap<
  string,
  Partial<Record<PriorSnippetField, string>>
>;

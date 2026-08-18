/** User-facing personal hypothesis — evidence case, not a static insight. */

export type PersonalTheoryStatus =
  | "under_review"
  | "strengthening"
  | "weakening"
  | "resolved"
  | "disproven";

export interface PersonalTheory {
  id: string;
  title: string;
  hypothesis: string;
  confidence: number;
  status: PersonalTheoryStatus;
  evidenceCount: number;
  contradictionCount: number;
  lifeAreas: string[];
  firstSeen: string;
  lastUpdated: string;
  whyConfidenceChanged: string;
  evidenceSummary: string;
  /** Prior confidence when movement is known. */
  previousConfidence?: number;
  confidenceDelta?: number;
}

export type TheoryCuriosityAnswer = "yes" | "maybe" | "no";

export interface TheoryCuriosityRecord {
  id: string;
  answer: TheoryCuriosityAnswer;
  at: string;
  reflectionCount: number;
}

export interface TheoryCuriosityReport {
  generatedAt: string;
  totalResponses: number;
  yesCount: number;
  maybeCount: number;
  noCount: number;
  /** Share of responses that were yes or maybe — founder metric. */
  theoryCuriosityRate: number;
}

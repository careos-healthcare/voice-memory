export type ResurfacingCooldownStatus = "clear" | "cooldown" | "fatigued" | "retired";

export type ResurfacingSafeDisplayMode =
  | "normal"
  | "cautious"
  | "change"
  | "suppressed";

/** Structured evidence for a resurfacing candidate — no emotional-AI claims. */
export interface ResurfacingEvidence {
  exactQuoteMatches: string[];
  repeatedPhrases: string[];
  sharedPeople: string[];
  sharedTopics: string[];
  sharedTimeWindow: string | null;
  emotionalShift: string | null;
  contradictionSignal: string | null;
  ambiguitySignal: string | null;
  sarcasmSignal: string | null;
  vaguenessSignal: string | null;
  priorUserAcceptance: number;
  priorUserRejection: number;
  stalenessDays: number;
  cooldownStatus: ResurfacingCooldownStatus;
  feedbackPenalties: string[];
  feedbackBoosts: string[];
  finalConfidence: number;
  evidenceScore: number;
  suppressionReasons: string[];
  cautiousWordingRequired: boolean;
}

export interface ResurfacingEvidenceGateResult {
  show: boolean;
  finalConfidence: number;
  suppressionReasons: string[];
  safeDisplayMode: ResurfacingSafeDisplayMode;
  evidence: ResurfacingEvidence;
  whySurfaced: string;
  displayText?: string;
}

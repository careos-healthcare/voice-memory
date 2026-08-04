export type AiUserFeedbackState =
  | "pending"
  | "correct"
  | "incorrect"
  | "later";

export interface AiAccuracyFeedback {
  conclusionId: string;
  engine: string;
  confidencePercentage: number;
  feedbackState: AiUserFeedbackState;
  feedbackTimestamp: string;
  correctionNote?: string;
  nodeIds: string[];
  edgeIds: string[];
}

export interface AiAccuracyMetrics {
  engine: string;
  correct: number;
  incorrect: number;
  later: number;
  verified: number;
  accuracyPercentage: number;
}

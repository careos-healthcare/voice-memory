export type TestimonialStatus = "pending" | "approved" | "rejected";

export type TestimonialEmotionalCategory =
  | "revisit"
  | "clarity_later"
  | "voice_return"
  | "quiet_continuity"
  | "trust"
  | "other";

export interface StoredTestimonial {
  id: string;
  text: string;
  emotionalCategory: TestimonialEmotionalCategory;
  status: TestimonialStatus;
  reason?: string;
  sourceCallbackIds: string[];
  retentionLinkages: string[];
  createdAt: string;
  updatedAt: string;
}

export interface EmotionalProofSnippet {
  id: string;
  text: string;
  source: "behavior" | "approved_testimonial" | "static";
  strength: number;
  evidence?: string;
}

export interface RememberedLaterRow {
  callbackId: string;
  text: string;
  kind: string;
  remembered72h: boolean;
  quotedBack: boolean;
  delayedRevisit: boolean;
  delayedReflection: boolean;
  copiedReopened: boolean;
  score: number;
}

export interface RememberedLaterReport {
  generatedAt: string;
  hasData: boolean;
  rows: RememberedLaterRow[];
  remembered72hCount: number;
  quotedBackCount: number;
  delayedRevisitCount: number;
  delayedReflectionCount: number;
  copiedReopenedCount: number;
}

export interface SocialProofReviewReport {
  generatedAt: string;
  hasData: boolean;
  approvedTestimonialCandidates: StoredTestimonial[];
  rejectedGenericTestimonials: StoredTestimonial[];
  revisitStories: Array<{ id: string; text: string; detail?: string }>;
  strongestResidueCallbacks: Array<{ id: string; text: string; score: number }>;
  revisitReflectionStories: Array<{ entryId: string; reflectionEntryId?: string; detail: string }>;
  copiedMoments: Array<{ id: string; text: string }>;
  remembered72hCallbacks: Array<{ id: string; text: string }>;
  overclaimedEmotionalLines: Array<{ id: string; text: string; reason: string }>;
  quietProofSnippets: EmotionalProofSnippet[];
}

export interface EmotionalLegitimacyScores {
  trustStrength: number;
  emotionalResidue: number;
  revisitAuthenticity: number;
  genericityRisk: number;
  overclaimRisk: number;
  silenceQuality: number;
  overall: number;
}

export interface EmotionalLegitimacyReport {
  generatedAt: string;
  hasData: boolean;
  scores: EmotionalLegitimacyScores;
  strongestBelievableLines: Array<{ id: string; text: string; score: number }>;
  weakestArtificialLines: Array<{ id: string; text: string; reason: string }>;
  rememberedLaterCallbacks: RememberedLaterRow[];
  ignoredInstantlyLines: Array<{ id: string; text: string; reason: string }>;
}

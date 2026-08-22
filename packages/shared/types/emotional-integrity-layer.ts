export type EmotionalIntegrityIssueKind =
  | "overclaiming"
  | "repetitive_framing"
  | "artificial_profundity"
  | "productivity_leakage"
  | "therapy_coaching_drift"
  | "engagement_pressure"
  | "emotional_exaggeration"
  | "synthetic_callback"
  | "copy_drift"
  | "manipulation_risk"
  | "monetization_trust_risk"
  | "sharing_cringe_risk"
  | "callback_fatigue"
  | "silence_degradation";

export interface EmotionalIntegrityWarning {
  id: string;
  kind: EmotionalIntegrityIssueKind;
  label: string;
  detail: string;
  severity: "watch" | "concern";
}

export interface RestraintRecommendation {
  id: string;
  text: string;
  action: "suppress" | "reduce" | "review" | "silence";
}

export interface SuppressionSuggestion {
  id: string;
  targetId: string;
  text: string;
  reason: string;
}

export interface EmotionalIntegrityReport {
  generatedAt: string;
  hasData: boolean;
  warnings: EmotionalIntegrityWarning[];
  restraintRecommendations: RestraintRecommendation[];
  suppressionSuggestions: SuppressionSuggestion[];
  emotionalDensityScore: number;
  explainingTooMuch: boolean;
  overdesigned: boolean;
  founderWarnings: string[];
}

export interface CallbackStructurePattern {
  id: string;
  pattern: string;
  label: string;
  count: number;
  examples: string[];
}

export interface CallbackDeduplicationReport {
  generatedAt: string;
  hasData: boolean;
  patterns: CallbackStructurePattern[];
  collapsedTemplates: string[];
  suppressionCandidates: Array<{ id: string; text: string; reason: string }>;
}

export interface ArchiveSimplicityRow {
  id: string;
  label: string;
  detail: string;
  category: "overlap" | "duplicate" | "unused" | "hotspot" | "redundant_surface";
}

export interface ArchiveSimplicityReport {
  generatedAt: string;
  hasData: boolean;
  rows: ArchiveSimplicityRow[];
  removalQuestion: string;
  overlapScore: number;
  overdesigned: boolean;
}

export interface RemovalReviewRow {
  id: string;
  label: string;
  detail: string;
  rank: "safe_to_remove" | "risky_to_keep" | "emotionally_dilutive";
  score: number;
}

export interface RemovalReviewReport {
  generatedAt: string;
  hasData: boolean;
  rows: RemovalReviewRow[];
  safeToRemove: RemovalReviewRow[];
  riskyToKeep: RemovalReviewRow[];
  emotionallyDilutive: RemovalReviewRow[];
}

export interface DurabilityReviewRow {
  id: string;
  label: string;
  detail: string;
  category:
    | "maintenance"
    | "sync"
    | "migration"
    | "dependency"
    | "lineage"
    | "corruption"
    | "continuity";
  severity: "watch" | "concern";
}

export interface DurabilityReviewReport {
  generatedAt: string;
  hasData: boolean;
  rows: DurabilityReviewRow[];
  maintenanceHotspots: number;
  continuityRiskScore: number;
}

export interface EmotionalIntegrityReviewReport {
  generatedAt: string;
  hasData: boolean;
  integrity: EmotionalIntegrityReport;
  deduplication: CallbackDeduplicationReport;
  simplicity: ArchiveSimplicityReport;
  removal: RemovalReviewReport;
  durability: DurabilityReviewReport;
  weakestArtificialCallbacks: Array<{ id: string; text: string; reason: string }>;
  repetitiveStructures: CallbackStructurePattern[];
  emotionalOverfitting: Array<{ id: string; text: string; detail: string }>;
  copyDrift: Array<{ id: string; text: string; detail: string }>;
  manipulationRisk: EmotionalIntegrityWarning[];
  monetizationTrustRisk: EmotionalIntegrityWarning[];
  sharingCringeRisk: EmotionalIntegrityWarning[];
  callbackFatigue: EmotionalIntegrityWarning[];
  silenceDegradation: EmotionalIntegrityWarning[];
}

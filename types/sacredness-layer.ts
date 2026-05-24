export interface SacrednessInflationWarning {
  id: string;
  kind:
    | "oversurfacing"
    | "too_many_meaningful"
    | "density_inflation"
    | "saturation"
    | "fatigue"
    | "diminished_contrast"
    | "big_callback_overuse"
    | "crowding";
  label: string;
  detail: string;
  severity: "watch" | "concern";
}

export interface SacrednessReport {
  generatedAt: string;
  hasData: boolean;
  sacrednessScore: number;
  emotionalRarityScore: number;
  silenceValueScore: number;
  inflationWarnings: SacrednessInflationWarning[];
  emotionallyCrowded: boolean;
  meaningfulnessInflated: boolean;
  silencePreferred: boolean;
  founderWarnings: string[];
}

export interface EarnedResurfacingRow {
  noteId: string;
  text: string;
  earnedScore: number;
  decayScore: number;
  exposureCount: number;
  earned: boolean;
  decayReason: string;
}

export interface EarnedResurfacingReport {
  generatedAt: string;
  hasData: boolean;
  rows: EarnedResurfacingRow[];
  earnedCount: number;
  decayedCount: number;
}

export interface SilenceFirstPolicy {
  active: boolean;
  reasons: string[];
  reduceResurfacing: boolean;
  preferEmptyStates: boolean;
  suppressInterpretation: boolean;
  suppressChanged: boolean;
  suppressIdentity: boolean;
  delayFollowups: boolean;
  spacingMultiplier: number;
}

export interface NonInterventionConclusion {
  id: string;
  text: string;
  confidence: number;
}

export interface NonInterventionReport {
  generatedAt: string;
  hasData: boolean;
  shouldSurfaceNothing: boolean;
  conclusions: NonInterventionConclusion[];
  silenceSuccessRate: number;
  revisitAfterSilenceCount: number;
  delayedCallbackEffectiveness: number;
}

export interface RestraintEscalationReport {
  generatedAt: string;
  hasData: boolean;
  level: number;
  entryCount: number;
  archiveSpanDays: number;
  showThresholdBoost: number;
  resurfacingReduction: number;
  silenceBias: number;
  evidenceRequirement: number;
  becomingMoreSpacious: boolean;
}

export interface RarityPreservationRow {
  id: string;
  text: string;
  rarityScore: number;
  protected: boolean;
  reason: string;
}

export interface RarityPreservationReport {
  generatedAt: string;
  hasData: boolean;
  protectedRows: RarityPreservationRow[];
  suppressedTemplateCount: number;
}

export interface DensityTrendPoint {
  period: string;
  density: number;
  resurfacingCount: number;
}

export interface SacrednessReviewReport {
  generatedAt: string;
  hasData: boolean;
  sacredness: SacrednessReport;
  earnedResurfacing: EarnedResurfacingReport;
  silenceFirst: SilenceFirstPolicy;
  nonIntervention: NonInterventionReport;
  escalation: RestraintEscalationReport;
  rarity: RarityPreservationReport;
  inflationTrend: DensityTrendPoint[];
  preservedStrongCallbacks: Array<{ id: string; text: string; score: number }>;
  dilutedCallbacks: Array<{ id: string; text: string; reason: string }>;
  silenceRatio: number;
  fatigueRisk: number;
  resurfacingDrift: number;
}

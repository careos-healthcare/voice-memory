/** Internal-only archive individuality — no personality typing, no user-visible labels. */

export type IndividualityStyleBand = "sparse" | "moderate" | "dense";

export interface ArchiveIndividualityProfile {
  generatedAt: string;
  hasData: boolean;
  entryCount: number;
  /** How the user reflects — intensity spread, observation density. */
  reflectionStyle: {
    avgIntensity: number;
    intensitySpread: number;
    observationDensity: IndividualityStyleBand;
  };
  /** Entry spacing and recovery rhythm. */
  pacingStyle: {
    medianEntryGapDays: number;
    typicalRecoveryDays: number;
    band: IndividualityStyleBand;
  };
  /** How silence and suppression behave for this archive. */
  silenceRhythm: {
    ignoredCooldownActive: boolean;
    sessionNoteTolerance: number;
    weakNoteSuppressed: boolean;
  };
  /** Distinct words and themes — not psychographics. */
  emotionalVocabulary: {
    uniqueTokenCount: number;
    themeCount: number;
    diversityScore: number;
  };
  /** Direct vs hedged naming in transcripts. */
  namingStyle: {
    avgHedge: number;
    avgDirect: number;
    certaintyBand: "hedged" | "mixed" | "direct";
  };
  /** Revisit spacing and fatigue. */
  revisitStyle: {
    fatigueScore: number;
    recommendedSpacingDays: number;
    revisitFatigueActive: boolean;
  };
  /** Follow-up and continuation behavior. */
  continuationStyle: {
    followupStarted: number;
    followupCompleted: number;
    continuationBand: IndividualityStyleBand;
  };
  /** Hedge/direct balance over time. */
  certaintyStyle: {
    hedgeDirectRatio: number;
    band: "hedged" | "mixed" | "direct";
  };
  /** How much emotional surfacing this archive tolerates. */
  emotionalDensityTolerance: {
    score: number;
    band: IndividualityStyleBand;
  };
  /** Single scalar — higher means more distinct from product defaults. */
  uniquenessScore: number;
}

export interface VoiceTextureMarker {
  id: string;
  kind: "hesitant" | "unfinished" | "personal" | "recurring" | "imperfect";
  text: string;
  sourceEntryId?: string;
}

export interface VoiceTextureReport {
  generatedAt: string;
  hasData: boolean;
  markers: VoiceTextureMarker[];
  protectedPhraseCount: number;
  polishRiskCount: number;
  shouldPreserveTexture: boolean;
}

export interface PersonalizedRestraintResult {
  allowed: boolean;
  reasons: string[];
  biasToward: string[];
}

export interface AntiTemplateResult {
  suppressed: boolean;
  warning: string | null;
  reasons: string[];
}

export interface LongitudinalIndividualityReport {
  generatedAt: string;
  hasData: boolean;
  earlyUniquenessScore: number;
  recentUniquenessScore: number;
  converging: boolean;
  becomingMoreUnique: boolean;
  signals: Array<{ id: string; label: string; detail: string }>;
}

export interface ArchiveIndividualityReviewReport {
  generatedAt: string;
  hasData: boolean;
  profile: ArchiveIndividualityProfile;
  voiceTexture: VoiceTextureReport;
  longitudinal: LongitudinalIndividualityReport;
  uniquenessMarkers: Array<{ id: string; label: string; detail: string }>;
  repeatedStructures: Array<{ id: string; label: string; count: number }>;
  phrasingCollapseRisk: number;
  vocabularyDiversity: number;
  revisitRhythmUniqueness: number;
  silenceBehaviorUniqueness: number;
  callbackSimilarityScore: number;
  founderWarnings: string[];
}

export interface ArchiveDivergenceRow {
  id: string;
  label: string;
  detail: string;
  category: "similar_archives" | "overused_family" | "spreading_structure" | "default_phrase";
  severity: "watch" | "concern";
}

export interface ArchiveDivergenceReviewReport {
  generatedAt: string;
  hasData: boolean;
  rows: ArchiveDivergenceRow[];
  divergenceQuestion: string;
  homogenizationScore: number;
  archivesConverging: boolean;
  specificityLoss: boolean;
  founderWarnings: string[];
  suggestions: string[];
}

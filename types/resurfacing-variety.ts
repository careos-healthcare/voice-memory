export type ResurfacingReturnMode =
  | "exact_echo"
  | "contradiction"
  | "silence_gap"
  | "escalation"
  | "recurrence_observation";

export interface ResurfacingModeDistributionRow {
  mode: ResurfacingReturnMode;
  label: string;
  shown: number;
  opened: number;
  reflectionAfter: number;
  openRate: number;
  reflectionRate: number;
}

export interface ResurfacingRepetitionWarning {
  severity: "watch" | "concern";
  message: string;
}

export interface OverusedPhraseRow {
  phrase: string;
  count: number;
  plain: string;
}

export interface CadenceClusterRow {
  cadenceKey: string;
  count: number;
  sampleLine: string;
  plain: string;
}

export interface ResurfacingFrequencyRow {
  label: string;
  active: boolean;
  plain: string;
}

export interface ResurfacingVarietyReport {
  generatedAt: string;
  hasData: boolean;
  scopeNote: string;
  recentModes: ResurfacingReturnMode[];
  modeDistribution: ResurfacingModeDistributionRow[];
  repetitionWarnings: ResurfacingRepetitionWarning[];
  overusedPhrases: OverusedPhraseRow[];
  cadenceClusters: CadenceClusterRow[];
  frequencyGates: ResurfacingFrequencyRow[];
  changeDetectionPlain: string;
  naturalVoicePlain: string;
}

import type { MemoryNote } from "@/types/memory-note";

export type MemoryCompoundingKind =
  | "phrase_gained_meaning"
  | "loop_resolving"
  | "wording_softened"
  | "fear_faded"
  | "identity_shift"
  | "clearer_later"
  | "almost_naming";

export type SlowRealizationKind =
  | "stopped_same_way"
  | "sounded_heavier"
  | "came_back_differently"
  | "carried_differently"
  | "easier_to_say";

export interface MemoryCompoundingCandidate {
  id: string;
  kind: MemoryCompoundingKind;
  text: string;
  strength: number;
  gapDays: number;
  supportingEntryIds: string[];
  pastEntryId?: string;
  entryId?: string;
  pastQuote?: string;
  currentQuote?: string;
}

export interface MemoryCompoundingReport {
  generatedAt: string;
  hasData: boolean;
  candidates: MemoryCompoundingCandidate[];
}

export interface SlowRealizationCandidate {
  id: string;
  kind: SlowRealizationKind;
  text: string;
  strength: number;
  gapDays: number;
  supportingCount: number;
  anchorEntryId: string;
  pastEntryId?: string;
  entryId?: string;
}

export interface SlowRealizationReport {
  generatedAt: string;
  hasData: boolean;
  candidates: SlowRealizationCandidate[];
  surfacedId: string | null;
}

export interface ArchiveDensitySignals {
  oldEntryReuseRate: number;
  quoteResurfacingRate: number;
  revisitDepthScore: number;
  continuitySurvivalScore: number;
  delayedRevisitReflectionRate: number;
  copiedReopenedWeeksLaterRate: number;
}

export interface ArchiveDepthReport {
  generatedAt: string;
  hasData: boolean;
  densityScore: number;
  densityTrend: "rising" | "flat" | "weak";
  signals: ArchiveDensitySignals;
  weakArchiveZones: Array<{ id: string; label: string; reason: string }>;
  strongestLongitudinalCallbacks: Array<{ id: string; text: string; score: number }>;
  densityHistory: Array<{ period: string; score: number }>;
}

export interface RevisitSequencingReport {
  generatedAt: string;
  hasData: boolean;
  revisitFatigueActive: boolean;
  fatigueScore: number;
  lastEmotionalReopenAt: string | null;
  suppressedAdjacentCount: number;
  recommendedSpacingDays: number;
}

export interface DurableCallbackRow {
  id: string;
  text: string;
  durableScore: number;
  revisits: number;
  copies: number;
  delayedReflections: number;
  survivesNovelty: boolean;
  noveltyOnly: boolean;
}

export interface DurableCallbacksReport {
  generatedAt: string;
  hasData: boolean;
  leaders: DurableCallbackRow[];
  fadedAfterNovelty: DurableCallbackRow[];
  noveltyOnly: DurableCallbackRow[];
}

export interface ArchiveMaturityReport {
  generatedAt: string;
  hasData: boolean;
  compounding: MemoryCompoundingReport;
  slowRealizations: SlowRealizationReport;
  archiveDepth: ArchiveDepthReport;
  revisitSequencing: RevisitSequencingReport;
  durableCallbacks: DurableCallbacksReport;
  revisitFatigueWarnings: string[];
  monthOverMonthContinuity: Array<{ month: string; score: number }>;
  longitudinalResidueLeaders: Array<{ id: string; text: string; score: number }>;
}

export type SlowRealizationNote = MemoryNote;

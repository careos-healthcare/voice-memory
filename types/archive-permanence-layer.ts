import type { MemoryNote } from "@/types/memory-note";

export type LifePeriodKind =
  | "moving"
  | "relationships_changing"
  | "burnout"
  | "grief_loss"
  | "career_shift"
  | "recovery"
  | "uncertainty"
  | "quieter_season";

export interface LifePeriod {
  id: string;
  kind: LifePeriodKind;
  text: string;
  startAt: string;
  endAt: string;
  entryIds: string[];
  strength: number;
}

export interface LifePeriodReport {
  generatedAt: string;
  hasData: boolean;
  periods: LifePeriod[];
}

export interface ArchiveLandmark {
  id: string;
  text: string;
  entryId: string;
  callbackId?: string;
  strength: number;
  evidence: string;
}

export interface ArchiveLandmarkReport {
  generatedAt: string;
  hasData: boolean;
  landmarks: ArchiveLandmark[];
  eligible: boolean;
}

export interface ContinuityIntegrityCheck {
  id: string;
  label: string;
  ok: boolean;
  detail: string;
}

export interface FutureContinuityReport {
  generatedAt: string;
  hasData: boolean;
  stableCallbackIds: string[];
  revisitLineageCount: number;
  quotePairCount: number;
  durableEntryLinks: number;
  checks: ContinuityIntegrityCheck[];
  migrationPreview: {
    resurfacingConsistent: boolean;
    quotePairsPersist: boolean;
    callbackIdsStable: boolean;
  };
}

export interface ArchivePermanenceManifest {
  schemaVersion: number;
  archiveVersion: number;
  exportedAt: string;
  entryCount: number;
  callbackFingerprint: string;
  integrityHash: string;
  audioReferenceCount: number;
  forwardCompatible: boolean;
}

export interface ArchiveGuaranteeReport {
  generatedAt: string;
  hasData: boolean;
  manifest: ArchivePermanenceManifest;
  restorationCompatible: boolean;
  schemaEvolutionSafe: boolean;
  exportLongevityScore: number;
  issues: Array<{ level: "error" | "warning"; message: string }>;
}

export interface PermanentCallbackRow {
  id: string;
  text: string;
  permanentScore: number;
  revisits: number;
  copies: number;
  delayedReflections: number;
  monthsSpan: number;
  archiveIdentity: boolean;
}

export interface PermanentCallbacksReport {
  generatedAt: string;
  hasData: boolean;
  permanent: PermanentCallbackRow[];
  suppressedNovelty: PermanentCallbackRow[];
  temporarySpikes: PermanentCallbackRow[];
}

export interface FutureArchiveHorizon {
  years: 1 | 3 | 5;
  projectedDensity: number;
  callbackDurability: number;
  revisitFatigueRisk: number;
  resurfacingRepetitionRisk: number;
  landmarkSurvival: number;
  continuityDrift: number;
  believable: boolean;
}

export interface FutureArchiveSimulationReport {
  generatedAt: string;
  hasData: boolean;
  currentArchiveSpanDays: number;
  horizons: FutureArchiveHorizon[];
}

export interface ArchivePermanenceReviewReport {
  generatedAt: string;
  hasData: boolean;
  permanentCallbacks: PermanentCallbacksReport;
  continuityBreakRisks: ContinuityIntegrityCheck[];
  migrationRisks: ArchiveGuaranteeReport["issues"];
  resurfacingRepetition: number;
  archiveDrift: number;
  weakFutureContinuity: string[];
  landmarks: ArchiveLandmarkReport;
  lifePeriods: LifePeriodReport;
  futureContinuity: FutureContinuityReport;
  guarantees: ArchiveGuaranteeReport;
}

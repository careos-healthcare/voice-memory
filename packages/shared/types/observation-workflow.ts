export type ReadinessCheckStatus = "pass" | "fail" | "warn" | "unknown";

export interface ReadinessCheck {
  id: string;
  label: string;
  status: ReadinessCheckStatus;
  detail: string;
}

export interface ProductionReadinessReport {
  generatedAt: string;
  checks: ReadinessCheck[];
  passed: number;
  failed: number;
  warnings: number;
  ready: boolean;
}

export interface MoatReviewMetric {
  id: string;
  label: string;
  current: string;
  currentValue: number;
  target: string;
  targetValue: number;
  met: boolean;
  countHint?: string;
}

export interface MoatReviewReport {
  generatedAt: string;
  metrics: MoatReviewMetric[];
  metCount: number;
  totalCount: number;
  hasData: boolean;
}

export type MonetizationGateVerdict = "blocked" | "test_carefully";

import type { MonetizationObservationReport } from "@/types/monetization-validation";

export interface MonetizationReadinessReport {
  generatedAt: string;
  verdict: MonetizationGateVerdict;
  headline: string;
  retentionChecks: ReadinessCheck[];
  moatChecks: ReadinessCheck[];
  trustChecks: ReadinessCheck[];
  syncChecks: ReadinessCheck[];
  archiveChecks: ReadinessCheck[];
  stripeRecommendation: string;
  allMet: boolean;
  softMonetization: MonetizationObservationReport;
  archiveProtectionInterest: number;
}

export type CallbackPruningAction = "cut" | "rewrite" | "keep" | "double_down";

export interface StoredCallbackPruningDecision {
  callbackId: string;
  action: CallbackPruningAction;
  noteText: string;
  updatedAt: string;
}

export interface CallbackPruningExportItem {
  id: string;
  kind: string;
  text: string;
  emotionalResidueScore: number;
  survivalScore: number;
  category: "weak" | "low_survival" | "generic" | "high_residue";
  recommendedAction: CallbackPruningAction;
  manualAction?: CallbackPruningAction;
}

export interface CallbackPruningExport {
  exportedAt: string;
  callbackCount: number;
  weakCallbacks: CallbackPruningExportItem[];
  lowSurvivalCallbacks: CallbackPruningExportItem[];
  genericCallbacks: CallbackPruningExportItem[];
  highResidueCallbacks: CallbackPruningExportItem[];
  decisions: StoredCallbackPruningDecision[];
}

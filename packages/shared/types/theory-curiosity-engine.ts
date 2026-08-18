import type { TheoryCuriosityAnswer, TheoryCuriosityReport } from "@/types/personal-theory";

export type TheoryMovementKind =
  | "confidence_increased"
  | "confidence_decreased"
  | "theory_retired";

export interface TheoryMovementItem {
  id: string;
  theoryId: string;
  kind: TheoryMovementKind;
  headline: string;
  why: string;
  fromConfidence?: number;
  toConfidence?: number;
  updatedAt: string;
}

export interface TheoryMovementFeedReport {
  generatedAt: string;
  hasBaseline: boolean;
  movements: TheoryMovementItem[];
  totalMovements: number;
}

export type TheoryCuriosityFunnelStepId =
  | "curiosity"
  | "discover_open"
  | "return_7d"
  | "paywall_click"
  | "subscription";

export interface TheoryCuriosityFunnelStep {
  id: TheoryCuriosityFunnelStepId;
  label: string;
  count: number;
  /** Rate from curious cohort (yes + maybe). */
  rateFromCuriousPercent: number | null;
  /** Conversion from previous funnel step. */
  rateFromPriorStepPercent: number | null;
}

export interface TheoryCuriosityEngineReport extends TheoryCuriosityReport {
  curiousCount: number;
  funnel: TheoryCuriosityFunnelStep[];
  leadingIndicatorLine: string;
  /** True when recent-window curiosity rate exceeds prior window. */
  curiosityRateRising: boolean | null;
  measurementNote: string;
}

export type { TheoryCuriosityAnswer };

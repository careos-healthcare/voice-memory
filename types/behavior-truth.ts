export type InsightConfidence = "low" | "moderate" | "high";

export interface BehaviorFunnelStep {
  id: string;
  label: string;
  numerator: number;
  denominator: number;
  percent: number;
  sampleNote: string;
  interpretation: string;
  confidence: InsightConfidence;
}

export interface ReturnTimingMetric {
  label: string;
  medianHours: number | null;
  sampleCount: number;
  plain: string;
}

export type UserReturnSegment =
  | "emotionally_active"
  | "one_and_done"
  | "quiet_returner"
  | "insufficient_data";

export interface UserReturnSegmentRow {
  segment: UserReturnSegment;
  label: string;
  plain: string;
  signals: string[];
}

export interface SurfaceEffectivenessRow {
  id: string;
  label: string;
  seen: number;
  opened: number;
  reflectedAfter: number;
  openRate: number;
  reflectionRate: number;
  verdict: "strong" | "mixed" | "ignored" | "insufficient";
  plain: string;
}

export interface CopyEffectivenessRow {
  lineKey: string;
  preview: string;
  shown: number;
  opened: number;
  reflectionsAfter: number;
  openRate: number;
  reflectionRate: number;
  generic: boolean;
  verdict: "strong" | "weak" | "ignored";
  plain: string;
}

export interface MobileBehaviorRow {
  label: string;
  value: string;
  plain: string;
}

export interface ProductPressureWarning {
  severity: "watch" | "concern";
  plain: string;
}

export interface BehaviorInsightLine {
  text: string;
  confidence: InsightConfidence;
  basedOn: string;
}

export interface BehaviorTruthReport {
  generatedAt: string;
  hasData: boolean;
  scopeNote: string;
  funnels: BehaviorFunnelStep[];
  returnTiming: ReturnTimingMetric[];
  userSegments: UserReturnSegmentRow[];
  surfaces: SurfaceEffectivenessRow[];
  strongestSurfaces: SurfaceEffectivenessRow[];
  ignoredSurfaces: SurfaceEffectivenessRow[];
  copyRows: CopyEffectivenessRow[];
  strongestCopy: CopyEffectivenessRow[];
  weakCopy: CopyEffectivenessRow[];
  mobile: MobileBehaviorRow[];
  productPressure: ProductPressureWarning[];
  insights: BehaviorInsightLine[];
}

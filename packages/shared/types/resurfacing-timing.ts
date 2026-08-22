export type ResurfacingTimingClass =
  | "too_early"
  | "cooling_down"
  | "eligible"
  | "strong_timing";

export interface ResurfacingTimingVerdict {
  noteId: string;
  entryId?: string;
  text: string;
  timingEligible: boolean;
  timingScore: number;
  timingClass: ResurfacingTimingClass;
  reasons: string[];
  suppressReasons: string[];
  nextEligibleAt: string | null;
}

export interface ResurfacingTimingReviewRow {
  noteId: string;
  entryId: string;
  text: string;
  timingEligible: boolean;
  timingScore: number;
  timingClass: ResurfacingTimingClass;
  reasons: string[];
  suppressReasons: string[];
  nextEligibleAt: string | null;
}

export interface ResurfacingTimingDebugReport {
  generatedAt: string;
  hasData: boolean;
  totalCandidates: number;
  tooEarly: ResurfacingTimingReviewRow[];
  coolingDown: ResurfacingTimingReviewRow[];
  eligible: ResurfacingTimingReviewRow[];
  strongTiming: ResurfacingTimingReviewRow[];
  topSuppressReasons: Array<{ reason: string; count: number }>;
  byClass: Record<ResurfacingTimingClass, number>;
}

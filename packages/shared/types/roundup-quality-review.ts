import type { ReflectiveRoundupSignal } from "@/types/reflective-roundup";

export type RoundupQualityReason =
  | "generic"
  | "repeat_theme_without_change"
  | "sounds_like_summary"
  | "lacks_source_entries"
  | "productivity_like"
  | "overclaims_change"
  | "could_apply_to_anyone";

export interface RoundupLineCandidate {
  text: string;
  entryIds: string[];
  signal: ReflectiveRoundupSignal;
  score: number;
}

export interface RoundupQualityVerdict {
  suppressed: boolean;
  reasons: RoundupQualityReason[];
}

export type RoundupReviewLabel =
  | "landed"
  | "generic"
  | "useful"
  | "too_productivity_like"
  | "worth_keeping";

export interface RoundupQualityReviewItem {
  id: string;
  periodSlug: string;
  periodLabel: string;
  text: string;
  signal: ReflectiveRoundupSignal;
  score: number;
  entryIds: string[];
  qualitySuppressed: boolean;
  qualityReasons: RoundupQualityReason[];
  selected: boolean;
  manualLabels: RoundupReviewLabel[];
}

export interface RoundupQualityReviewPeriod {
  periodSlug: string;
  periodLabel: string;
  startDayKey: string;
  endDayKey: string;
  items: RoundupQualityReviewItem[];
  selectedCount: number;
  suppressedCount: number;
}

export interface RoundupQualityReviewReport {
  generatedAt: string;
  periods: RoundupQualityReviewPeriod[];
  totalCandidates: number;
  totalSuppressed: number;
  totalSelected: number;
  byReason: Partial<Record<RoundupQualityReason, number>>;
  hasData: boolean;
}

export const ROUNDUP_REVIEW_LABELS: Array<{ value: RoundupReviewLabel; label: string }> = [
  { value: "landed", label: "Landed" },
  { value: "generic", label: "Generic" },
  { value: "useful", label: "Useful" },
  { value: "too_productivity_like", label: "Too productivity-like" },
  { value: "worth_keeping", label: "Worth keeping" },
];

export const ROUNDUP_QUALITY_REASON_LABELS: Record<RoundupQualityReason, string> = {
  generic: "Generic",
  repeat_theme_without_change: "Repeat theme without change",
  sounds_like_summary: "Sounds like a summary",
  lacks_source_entries: "Lacks source entries",
  productivity_like: "Productivity-like",
  overclaims_change: "Overclaims change",
  could_apply_to_anyone: "Could apply to anyone",
};

export type CallbackReviewKind =
  | "memory_callback"
  | "then_vs_now"
  | "resurfacing"
  | "revisitation"
  | "change_moment"
  | "continuity_line"
  | "milestone"
  | "relationship_continuity"
  | "archive_growth"
  | "memory_reminder"
  | "continuity_depth"
  | "familiarity"
  | "familiarity_resurfacing"
  | "rhythm"
  | "time_memory";

export type CallbackReviewLabel =
  | "landed_emotionally"
  | "felt_generic"
  | "too_analytical"
  | "too_obvious"
  | "emotionally_precise"
  | "memorable"
  | "invasive"
  | "cold"
  | "comforting"
  | "worth_revisiting"
  | "high_emotional_residue"
  | "forgettable";

export type RewriteCandidateFlag =
  | "generic_wording"
  | "templated"
  | "over_explains"
  | "lacks_specificity"
  | "lacks_emotional_contrast"
  | "could_apply_to_many";

export interface CallbackRetentionSummary {
  surfaced: number;
  ignored: number;
  reread: number;
  revisit: number;
  recording: number;
  bookmark: number;
  copied: number;
}

export interface CallbackInteractionSignals {
  rereadCount: number;
  revisitCount: number;
  bookmarked: boolean;
  bookmarkTypes: string[];
  memoryMomentCopied: boolean;
  dwellMs: number;
  followupContinued: boolean;
}

export interface CallbackSourceEntry {
  id: string;
  dateLabel: string;
  snippet: string;
  href: string;
}

export interface CallbackReviewItem {
  id: string;
  kind: CallbackReviewKind;
  text: string;
  surfaces: string[];
  sourceEntries: CallbackSourceEntry[];
  beforeQuote?: string;
  afterQuote?: string;
  beforeDateLabel?: string;
  afterDateLabel?: string;
  whySurfaced: string;
  emotionalWeight: number;
  confidence: number;
  rewriteFlags: RewriteCandidateFlag[];
  signals: CallbackInteractionSignals;
  retention: CallbackRetentionSummary;
  followupNoteId?: string;
  followupPrompt?: string;
  continuedFollowup: boolean;
}

export interface CallbackQualityReviewReport {
  items: CallbackReviewItem[];
  rewriteCandidateCount: number;
  labeledCount: number;
  hasData: boolean;
}

export const CALLBACK_REVIEW_LABELS: Array<{
  value: CallbackReviewLabel;
  label: string;
}> = [
  { value: "landed_emotionally", label: "Landed emotionally" },
  { value: "felt_generic", label: "Felt generic" },
  { value: "too_analytical", label: "Too analytical" },
  { value: "too_obvious", label: "Too obvious" },
  { value: "emotionally_precise", label: "Emotionally precise" },
  { value: "memorable", label: "Memorable" },
  { value: "invasive", label: "Invasive" },
  { value: "cold", label: "Cold" },
  { value: "comforting", label: "Comforting" },
  { value: "worth_revisiting", label: "Worth revisiting" },
  { value: "high_emotional_residue", label: "High emotional residue" },
  { value: "forgettable", label: "Forgettable" },
];

export const REWRITE_FLAG_LABELS: Record<RewriteCandidateFlag, string> = {
  generic_wording: "Reuses generic wording",
  templated: "Sounds templated",
  over_explains: "Over-explains",
  lacks_specificity: "Lacks specificity",
  lacks_emotional_contrast: "Lacks emotional contrast",
  could_apply_to_many: "Could apply to many users",
};

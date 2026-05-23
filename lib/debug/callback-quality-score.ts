import type {
  CallbackReviewItem,
  CallbackReviewLabel,
  RewriteCandidateFlag,
} from "@/types/callback-quality-review";

const POSITIVE_LABELS: CallbackReviewLabel[] = [
  "landed_emotionally",
  "memorable",
  "emotionally_precise",
  "high_emotional_residue",
  "comforting",
  "worth_revisiting",
];

const NEGATIVE_LABELS: CallbackReviewLabel[] = [
  "felt_generic",
  "too_analytical",
  "forgettable",
  "too_obvious",
  "cold",
  "invasive",
];

type ResidueInput = Pick<
  CallbackReviewItem,
  "signals" | "retention" | "continuedFollowup"
>;

/** Engagement-weighted score — how much residue a line left behind. */
export function computeEmotionalResidueScore(
  item: ResidueInput,
  labels: CallbackReviewLabel[] = [],
): number {
  let score = 0;

  const rereads = Math.max(item.retention.reread, item.signals.rereadCount);
  const revisits = Math.max(item.retention.revisit, item.signals.revisitCount);

  score += Math.min(32, rereads * 10);
  score += Math.min(28, revisits * 12);
  if (item.retention.bookmark > 0 || item.signals.bookmarked) score += 20;
  if (item.retention.copied > 0 || item.signals.memoryMomentCopied) score += 22;
  if (item.continuedFollowup || item.retention.recording > 0) score += 24;
  score += Math.min(18, Math.round(item.signals.dwellMs / 4500));

  if (labels.includes("high_emotional_residue")) score += 25;
  if (labels.includes("landed_emotionally")) score += 14;
  if (labels.includes("memorable")) score += 12;
  if (labels.includes("forgettable")) score -= 22;
  if (labels.includes("felt_generic")) score -= 16;

  return Math.max(0, Math.round(score));
}

/** Combined tuning score — engagement + manual review + copy quality. */
export function computeQualityScore(
  item: Pick<
    CallbackReviewItem,
    | "signals"
    | "retention"
    | "continuedFollowup"
    | "rewriteFlags"
    | "confidence"
    | "emotionalWeight"
  >,
  labels: CallbackReviewLabel[],
  emotionalResidue: number,
): number {
  let score = emotionalResidue * 0.55;

  for (const label of labels) {
    if (POSITIVE_LABELS.includes(label)) score += 11;
    if (NEGATIVE_LABELS.includes(label)) score -= 13;
  }

  score -= item.rewriteFlags.length * 7;
  score += Math.min(12, item.confidence / 9);
  score += Math.min(8, item.emotionalWeight / 12);

  return Math.max(0, Math.round(score));
}

export function isCutCandidate(
  qualityScore: number,
  emotionalResidue: number,
  labels: CallbackReviewLabel[],
  rewriteFlags: RewriteCandidateFlag[],
): boolean {
  if (qualityScore < 22) return true;
  if (labels.includes("felt_generic") || labels.includes("forgettable")) return true;
  if (labels.includes("too_analytical") && emotionalResidue < 25) return true;
  if (rewriteFlags.length >= 2 && emotionalResidue < 18) return true;
  return false;
}

export function isDoubleDown(
  item: ResidueInput,
  emotionalResidue: number,
  labels: CallbackReviewLabel[],
): boolean {
  if (labels.includes("high_emotional_residue")) return true;
  if (emotionalResidue >= 58) return true;
  if (labels.includes("landed_emotionally") && labels.includes("memorable")) return true;

  const reread =
    item.retention.reread > 0 ||
    item.signals.rereadCount > 0 ||
    item.retention.revisit > 0 ||
    item.signals.revisitCount > 0;
  const action =
    item.signals.bookmarked ||
    item.signals.memoryMomentCopied ||
    item.continuedFollowup ||
    item.retention.recording > 0;

  return reread && action;
}

export type CallbackReviewFilter =
  | "all"
  | "cut_candidate"
  | "double_down"
  | "rewrite"
  | "landed_emotionally"
  | "felt_generic"
  | "too_analytical"
  | "memorable"
  | "reread"
  | "revisited"
  | "bookmarked"
  | "copied"
  | "followup_continued";

export const CALLBACK_REVIEW_FILTERS: Array<{
  value: CallbackReviewFilter;
  label: string;
}> = [
  { value: "all", label: "All" },
  { value: "double_down", label: "Double down" },
  { value: "cut_candidate", label: "Cut candidate" },
  { value: "rewrite", label: "Rewrite" },
  { value: "landed_emotionally", label: "Landed emotionally" },
  { value: "felt_generic", label: "Felt generic" },
  { value: "too_analytical", label: "Too analytical" },
  { value: "memorable", label: "Memorable" },
  { value: "reread", label: "Reread" },
  { value: "revisited", label: "Revisited" },
  { value: "bookmarked", label: "Bookmarked" },
  { value: "copied", label: "Copied" },
  { value: "followup_continued", label: "Follow-up continued" },
];

export function matchesCallbackFilter(
  item: CallbackReviewItem,
  filter: CallbackReviewFilter,
  labels: CallbackReviewLabel[],
): boolean {
  if (filter === "all") return true;
  if (filter === "cut_candidate") return item.cutCandidate;
  if (filter === "double_down") return item.doubleDown;
  if (filter === "rewrite") return item.rewriteFlags.length > 0;

  if (filter === "landed_emotionally") return labels.includes("landed_emotionally");
  if (filter === "felt_generic") return labels.includes("felt_generic");
  if (filter === "too_analytical") return labels.includes("too_analytical");
  if (filter === "memorable") return labels.includes("memorable");

  if (filter === "reread") {
    return item.retention.reread > 0 || item.signals.rereadCount > 0;
  }
  if (filter === "revisited") {
    return item.retention.revisit > 0 || item.signals.revisitCount > 0;
  }
  if (filter === "bookmarked") {
    return item.retention.bookmark > 0 || item.signals.bookmarked;
  }
  if (filter === "copied") {
    return item.retention.copied > 0 || item.signals.memoryMomentCopied;
  }
  if (filter === "followup_continued") {
    return item.continuedFollowup || item.retention.recording > 0;
  }

  return true;
}

export function enrichCallbackReviewItem(
  item: CallbackReviewItem,
  labels: CallbackReviewLabel[],
): CallbackReviewItem {
  const emotionalResidueScore = computeEmotionalResidueScore(item, labels);
  const qualityScore = computeQualityScore(item, labels, emotionalResidueScore);

  return {
    ...item,
    manualLabels: labels,
    emotionalResidueScore,
    qualityScore,
    cutCandidate: isCutCandidate(
      qualityScore,
      emotionalResidueScore,
      labels,
      item.rewriteFlags,
    ),
    doubleDown: isDoubleDown(item, emotionalResidueScore, labels),
  };
}

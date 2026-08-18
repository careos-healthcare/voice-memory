import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import { sortByEmotionalSurvival } from "@/lib/debug/callback-quality-score";
import type {
  CallbackQualityReviewReport,
  CallbackReviewItem,
  CallbackSurvivalAnalysis,
} from "@/types/callback-quality-review";

export interface CallbackReviewExport {
  exportedAt: string;
  callbackCount: number;
  labeledCount: number;
  cutCandidateCount: number;
  doubleDownCount: number;
  survived24hCount: number;
  survived72hCount: number;
  lowSurvivalCutCount: number;
  items: CallbackQualityReviewReport["items"];
  reviews: ReturnType<typeof readAllCallbackReviews>;
  survivalReview: CallbackSurvivalReviewExport;
  topSurvivingCallbacks: CallbackSurvivalSnapshot[];
  bottomWeakCallbacks: CallbackSurvivalSnapshot[];
}

export interface CallbackSurvivalSnapshot {
  id: string;
  kind: CallbackReviewItem["kind"];
  text: string;
  emotionalSurvivalScore: number;
  survival: CallbackSurvivalAnalysis;
}

export interface CallbackSurvivalReviewExport {
  exportedAt: string;
  callbackCount: number;
  survived24hCount: number;
  survived72hCount: number;
  lowSurvivalCutCount: number;
  items: Array<{
    id: string;
    kind: CallbackReviewItem["kind"];
    text: string;
    sourceLocation: CallbackReviewItem["sourceLocation"];
    survival: CallbackSurvivalAnalysis;
    manualLabels: CallbackReviewItem["manualLabels"];
  }>;
}

const SURVIVAL_RANK_LIMIT = 12;

function toSurvivalSnapshot(item: CallbackReviewItem): CallbackSurvivalSnapshot {
  return {
    id: item.id,
    kind: item.kind,
    text: item.text,
    emotionalSurvivalScore: item.survival.emotionalSurvivalScore,
    survival: item.survival,
  };
}

export function buildCallbackSurvivalReview(
  report: CallbackQualityReviewReport,
): CallbackSurvivalReviewExport {
  return {
    exportedAt: new Date().toISOString(),
    callbackCount: report.items.length,
    survived24hCount: report.survived24hCount,
    survived72hCount: report.survived72hCount,
    lowSurvivalCutCount: report.lowSurvivalCutCount,
    items: report.items.map((item) => ({
      id: item.id,
      kind: item.kind,
      text: item.text,
      sourceLocation: item.sourceLocation,
      survival: item.survival,
      manualLabels: item.manualLabels,
    })),
  };
}

export function buildCallbackReviewExport(
  report: CallbackQualityReviewReport,
): CallbackReviewExport {
  const ranked = sortByEmotionalSurvival(report.items);

  return {
    exportedAt: new Date().toISOString(),
    callbackCount: report.items.length,
    labeledCount: report.labeledCount,
    cutCandidateCount: report.cutCandidateCount,
    doubleDownCount: report.doubleDownCount,
    survived24hCount: report.survived24hCount,
    survived72hCount: report.survived72hCount,
    lowSurvivalCutCount: report.lowSurvivalCutCount,
    items: report.items,
    reviews: readAllCallbackReviews(),
    survivalReview: buildCallbackSurvivalReview(report),
    topSurvivingCallbacks: ranked.slice(0, SURVIVAL_RANK_LIMIT).map(toSurvivalSnapshot),
    bottomWeakCallbacks: [...ranked]
      .reverse()
      .slice(0, SURVIVAL_RANK_LIMIT)
      .map(toSurvivalSnapshot),
  };
}

/** Download local callback review as JSON — debug only. */
export function downloadCallbackReviewJson(report: CallbackQualityReviewReport): void {
  if (typeof window === "undefined") return;

  const payload = buildCallbackReviewExport(report);
  const blob = new Blob([JSON.stringify(payload, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  const stamp = payload.exportedAt.slice(0, 10);
  anchor.href = url;
  anchor.download = `voicememory-callback-review-${stamp}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

/** Download survival-focused review JSON — debug only. */
export function downloadCallbackSurvivalJson(report: CallbackQualityReviewReport): void {
  if (typeof window === "undefined") return;

  const ranked = sortByEmotionalSurvival(report.items);
  const payload = {
    exportedAt: new Date().toISOString(),
    survivalReview: buildCallbackSurvivalReview(report),
    topSurvivingCallbacks: ranked.slice(0, SURVIVAL_RANK_LIMIT).map(toSurvivalSnapshot),
    bottomWeakCallbacks: [...ranked]
      .reverse()
      .slice(0, SURVIVAL_RANK_LIMIT)
      .map(toSurvivalSnapshot),
  };

  const blob = new Blob([JSON.stringify(payload, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  const stamp = payload.exportedAt.slice(0, 10);
  anchor.href = url;
  anchor.download = `voicememory-callback-survival-${stamp}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

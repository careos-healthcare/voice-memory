import { readAllCallbackReviews } from "@/lib/debug/callback-review-labels";
import type { CallbackQualityReviewReport } from "@/types/callback-quality-review";

export interface CallbackReviewExport {
  exportedAt: string;
  callbackCount: number;
  labeledCount: number;
  cutCandidateCount: number;
  doubleDownCount: number;
  items: CallbackQualityReviewReport["items"];
  reviews: ReturnType<typeof readAllCallbackReviews>;
}

export function buildCallbackReviewExport(
  report: CallbackQualityReviewReport,
): CallbackReviewExport {
  return {
    exportedAt: new Date().toISOString(),
    callbackCount: report.items.length,
    labeledCount: report.labeledCount,
    cutCandidateCount: report.cutCandidateCount,
    doubleDownCount: report.doubleDownCount,
    items: report.items,
    reviews: readAllCallbackReviews(),
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

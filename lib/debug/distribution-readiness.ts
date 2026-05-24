import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import {
  buildEligibleQuietShareCards,
  scanCringeRiskLines,
  scoreShareableLine,
} from "@/lib/sharing/quiet-sharing";
import {
  buildShareObservationReport,
  hasCompletedCreatorPreview,
  inviteReturnConversionRate,
} from "@/lib/sharing/share-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { DistributionReadinessReport } from "@/types/sharing";

function emotionalClarityScore(entries: ReturnType<typeof getMemoryEligibleEntries>): number {
  const report = buildCallbackQualityReviewReport(entries);
  if (report.items.length === 0) return 0;
  const avg =
    report.items.reduce((sum, item) => sum + item.emotionalResidueScore, 0) /
    report.items.length;
  return Math.round(avg);
}

export function buildDistributionReadinessReport(): DistributionReadinessReport {
  const entries = getMemoryEligibleEntries();
  const shareObservation = buildShareObservationReport();
  const cards = buildEligibleQuietShareCards(entries);
  const callbackReport = buildCallbackQualityReviewReport(entries);

  const lineCandidates = [
    ...cards.map((card) => ({ id: card.id, text: card.line })),
    ...callbackReport.items.slice(0, 20).map((item) => ({ id: item.id, text: item.text })),
  ];

  const mostShareableGroundedLines = [...lineCandidates]
    .map((row) => ({ ...row, score: scoreShareableLine(row.text) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 10);

  const cringeRiskLines = scanCringeRiskLines(lineCandidates).slice(0, 12);

  const shareCount = shareObservation.sharedCallbacksCount + shareObservation.sharedRevisitMomentsCount;
  const revisitAfterShareConversion =
    shareCount > 0
      ? Math.round((shareObservation.revisitAfterShareCount / shareCount) * 100)
      : 0;

  const creatorPreviewCompletionRate = hasCompletedCreatorPreview() ? 100 : 0;

  return {
    generatedAt: new Date().toISOString(),
    hasData: lineCandidates.length > 0 || shareObservation.hasData,
    emotionalClarityScore: emotionalClarityScore(entries),
    creatorPreviewCompletionRate,
    inviteReturnConversion: inviteReturnConversionRate(),
    revisitAfterShareConversion,
    mostShareableGroundedLines,
    cringeRiskLines,
    copiedBeforeSharedCallbacks: shareObservation.copiedBeforeShared,
    shareObservation,
  };
}

export function downloadDistributionReadinessJson(
  report: DistributionReadinessReport = buildDistributionReadinessReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "distribution-readiness.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

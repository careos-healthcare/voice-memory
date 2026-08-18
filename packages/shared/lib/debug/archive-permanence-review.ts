import { buildArchiveDepthReport } from "@/lib/debug/archive-depth-review";
import { buildArchiveGuaranteeReport } from "@/lib/archive/archive-guarantees";
import { buildArchiveLandmarkReport } from "@/lib/archive/archive-landmarks";
import { buildFutureContinuityReport } from "@/lib/archive/future-continuity";
import { buildLifePeriodReport } from "@/lib/archive/life-periods";
import { buildFutureArchiveSimulationReport } from "@/lib/debug/future-archive-review";
import { buildPermanentCallbacksReport } from "@/lib/refinement/permanent-callbacks";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { ArchivePermanenceReviewReport } from "@/types/archive-permanence-layer";

export function buildArchivePermanenceReviewReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchivePermanenceReviewReport {
  const permanentCallbacks = buildPermanentCallbacksReport(entries);
  const futureContinuity = buildFutureContinuityReport(entries);
  const guarantees = buildArchiveGuaranteeReport();
  const landmarks = buildArchiveLandmarkReport(entries);
  const lifePeriods = buildLifePeriodReport(entries);
  const depth = buildArchiveDepthReport(entries);
  const sequencing = buildRevisitSequencingReport();
  const futureArchive = buildFutureArchiveSimulationReport(entries);

  const continuityBreakRisks = futureContinuity.checks.filter((c) => !c.ok);

  const fiveYear = futureArchive.horizons.find((h) => h.years === 5);
  const resurfacingRepetition = fiveYear?.resurfacingRepetitionRisk ?? sequencing.fatigueScore * 3;
  const archiveDrift =
    fiveYear?.continuityDrift ?? (depth.densityTrend === "weak" ? 40 : 20);

  const weakFutureContinuity: string[] = [];
  if (!futureContinuity.migrationPreview.callbackIdsStable) {
    weakFutureContinuity.push("Callback ids may not survive migration");
  }
  if (!futureContinuity.migrationPreview.quotePairsPersist) {
    weakFutureContinuity.push("Quote pairs not yet durable enough");
  }
  if (!guarantees.restorationCompatible) {
    weakFutureContinuity.push("Current export may not restore cleanly");
  }
  if (landmarks.eligible && landmarks.landmarks.length === 0) {
    weakFutureContinuity.push("No landmarks survived durability filtering");
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length >= 4 || depth.hasData,
    permanentCallbacks,
    continuityBreakRisks,
    migrationRisks: guarantees.issues,
    resurfacingRepetition,
    archiveDrift,
    weakFutureContinuity,
    landmarks,
    lifePeriods,
    futureContinuity,
    guarantees,
  };
}

export function downloadArchivePermanenceReviewJson(
  report: ArchivePermanenceReviewReport = buildArchivePermanenceReviewReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "archive-permanence-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

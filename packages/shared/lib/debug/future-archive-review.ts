import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildArchiveDepthReport } from "@/lib/debug/archive-depth-review";
import { buildArchiveLandmarkReport } from "@/lib/archive/archive-landmarks";
import { buildFutureContinuityReport } from "@/lib/archive/future-continuity";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  FutureArchiveHorizon,
  FutureArchiveSimulationReport,
} from "@/types/archive-permanence-layer";

function archiveSpanDays(entries: JournalEntry[]): number {
  if (entries.length < 2) return 0;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  return daysBetweenKeys(toDayKey(sorted[0].createdAt), toDayKey(sorted[sorted.length - 1].createdAt));
}

function simulateHorizon(
  entries: JournalEntry[],
  years: 1 | 3 | 5,
  depth: ReturnType<typeof buildArchiveDepthReport>,
  continuity: ReturnType<typeof buildFutureContinuityReport>,
  landmarks: ReturnType<typeof buildArchiveLandmarkReport>,
  sequencing: ReturnType<typeof buildRevisitSequencingReport>,
): FutureArchiveHorizon {
  const spanDays = archiveSpanDays(entries);
  const projectedDays = spanDays + years * 365;
  const densityDecay = Math.max(0.55, 1 - years * 0.08);
  const projectedDensity = Math.round(depth.densityScore * densityDecay);

  const callbackDurability = Math.min(
    100,
    Math.round(
      (continuity.stableCallbackIds.length / Math.max(entries.length * 0.15, 1)) * 100 * densityDecay,
    ),
  );

  const revisitFatigueRisk = Math.min(
    100,
    Math.round(
      (sequencing.revisitFatigueActive ? 45 : 15) +
        sequencing.fatigueScore * 2 +
        years * 6,
    ),
  );

  const failedChecks = continuity.checks.filter((c) => !c.ok).length;
  const resurfacingRepetitionRisk = Math.min(
    100,
    Math.round(failedChecks * 18 + (sequencing.suppressedAdjacentCount > 2 ? 25 : 10) + years * 5),
  );

  const landmarkSurvival = landmarks.eligible
    ? Math.max(0, Math.round(landmarks.landmarks.length * 45 - years * 8))
    : Math.round(20 - years * 3);

  const continuityDrift = Math.min(
    100,
    Math.round(
      years * 12 +
        (continuity.durableEntryLinks < 2 ? 20 : 0) +
        (continuity.quotePairCount === 0 && entries.length >= 10 ? 15 : 0),
    ),
  );

  const believable =
    projectedDensity >= 35 &&
    callbackDurability >= 30 &&
    revisitFatigueRisk <= 70 &&
    resurfacingRepetitionRisk <= 65 &&
    continuityDrift <= 55;

  void projectedDays;

  return {
    years,
    projectedDensity,
    callbackDurability,
    revisitFatigueRisk,
    resurfacingRepetitionRisk,
    landmarkSurvival,
    continuityDrift,
    believable,
  };
}

/** Simulate archive emotional believability at 1, 3, and 5 year horizons. */
export function buildFutureArchiveSimulationReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FutureArchiveSimulationReport {
  const depth = buildArchiveDepthReport(entries);
  const continuity = buildFutureContinuityReport(entries);
  const landmarks = buildArchiveLandmarkReport(entries);
  const sequencing = buildRevisitSequencingReport();

  const horizons: FutureArchiveHorizon[] = ([1, 3, 5] as const).map((years) =>
    simulateHorizon(entries, years, depth, continuity, landmarks, sequencing),
  );

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length >= 4,
    currentArchiveSpanDays: archiveSpanDays(entries),
    horizons,
  };
}

export function downloadFutureArchiveJson(
  report: FutureArchiveSimulationReport = buildFutureArchiveSimulationReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "future-archive-simulation.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

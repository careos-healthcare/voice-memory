import {
  countActiveInternalDashboards,
  countArchivedInternalDashboards,
  getDiscoverableInternalRoutes,
  getInternalArchiveRegistry,
  internalSurfaceReductionRatio,
  INTERNAL_SURFACE_REDUCTION_TARGET,
} from "@/lib/internal/internal-archive-registry";
import { buildNorthStarDashboard, NORTH_STAR_METRIC_COUNT } from "@/lib/internal/north-star-report";
import type { FounderFocusScoreReport } from "@/types/internal-archive";

export const FOUNDER_FOCUS_SCORE_TARGET = 90;

export function buildFounderFocusScore(): FounderFocusScoreReport {
  const activeDashboards = countActiveInternalDashboards();
  const archivedDashboards = countArchivedInternalDashboards();
  const deleteCandidates = getInternalArchiveRegistry().filter(
    (r) => r.status === "DELETE_CANDIDATE",
  ).length;
  const discoverableRoutes = getDiscoverableInternalRoutes().length;
  const reduction = internalSurfaceReductionRatio();

  const northStar = buildNorthStarDashboard();
  const northStarCoverage = Math.round(
    (northStar.metrics.filter((m) => m.value !== null).length / NORTH_STAR_METRIC_COUNT) * 100,
  );

  let score = 0;
  if (activeDashboards <= 7) score += 28;
  else if (activeDashboards <= 12) score += 18;
  else score += 5;

  if (discoverableRoutes <= 7) score += 22;
  else if (discoverableRoutes <= 10) score += 12;

  if (reduction >= INTERNAL_SURFACE_REDUCTION_TARGET) score += 30;
  else if (reduction >= 0.5) score += 15;

  score += Math.min(20, Math.round(northStarCoverage / 5));

  const finalScore = Math.min(100, score);

  const summary =
    finalScore >= FOUNDER_FOCUS_SCORE_TARGET
      ? "Founder tooling is consolidated — five pillars cover activation, return, conversion, distribution, and mobile."
      : "Tighten discoverable routes and archive more panels until focus score reaches 90+.";

  return {
    score: finalScore,
    target: FOUNDER_FOCUS_SCORE_TARGET,
    activeDashboards,
    archivedDashboards,
    deleteCandidates,
    discoverableRoutes,
    northStarCoverage,
    summary,
  };
}

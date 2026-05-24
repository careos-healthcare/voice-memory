import { buildSacrednessReport, weeklyDensityTrend } from "@/lib/restraint/sacredness";
import { buildEarnedResurfacingReport } from "@/lib/restraint/earned-resurfacing";
import { getSilenceFirstPolicy } from "@/lib/restraint/silence-first";
import { buildNonInterventionReport } from "@/lib/restraint/non-intervention";
import { buildRestraintEscalationReport } from "@/lib/restraint/restraint-escalation";
import { buildRarityPreservationReport } from "@/lib/refinement/rarity-preservation";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildLoopOptimizationReport } from "@/lib/retention/loop-optimization";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { SacrednessReviewReport } from "@/types/sacredness-layer";

/** Founder sacredness review — inflation, rarity, silence ratio. */
export function buildSacrednessReviewReport(): SacrednessReviewReport {
  const entries = getMemoryEligibleEntries();
  const sacredness = buildSacrednessReport(entries);
  const earnedResurfacing = buildEarnedResurfacingReport(entries);
  const silenceFirst = getSilenceFirstPolicy(entries);
  const nonIntervention = buildNonInterventionReport(entries);
  const escalation = buildRestraintEscalationReport(entries);
  const rarity = buildRarityPreservationReport(entries);
  const callbacks = buildCallbackQualityReviewReport(entries);
  const loopOpt = buildLoopOptimizationReport(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const inflationTrend = weeklyDensityTrend(entries);

  const preservedStrong = loopOpt.topPerforming
    .filter((r) => r.residueScore >= 55 && r.surfaces <= 3)
    .slice(0, 6)
    .map((r) => ({
      id: r.noteId,
      text: r.noteText.slice(0, 100),
      score: r.residueScore,
    }));

  const diluted = callbacks.items
    .filter(
      (i) =>
        i.survival.emotionalSurvivalScore < 25 &&
        loopOpt.topPerforming.some((r) => r.noteId === i.id && r.surfaces >= 3),
    )
    .slice(0, 6)
    .map((i) => ({
      id: i.id,
      text: i.text.slice(0, 100),
      reason: "Overexposed with low survival",
    }));

  const silenceRatio = Math.round(
    ((silence.weakNoteSuppressed ? 1 : 0) +
      (silence.ignoredCooldownActive ? 1 : 0) +
      (nonIntervention.shouldSurfaceNothing ? 1 : 0)) /
      3 *
      100,
  );

  const fatigueRisk = Math.min(
    100,
    sacredness.inflationWarnings.filter((w) => w.kind === "fatigue" || w.kind === "saturation").length * 25 +
      (silenceFirst.active ? 30 : 0),
  );

  const resurfacingDrift =
    inflationTrend.length >= 2
      ? inflationTrend[inflationTrend.length - 1].density - inflationTrend[0].density
      : 0;

  return {
    generatedAt: new Date().toISOString(),
    hasData: sacredness.hasData || entries.length > 0,
    sacredness,
    earnedResurfacing,
    silenceFirst,
    nonIntervention,
    escalation,
    rarity,
    inflationTrend,
    preservedStrongCallbacks: preservedStrong,
    dilutedCallbacks: diluted,
    silenceRatio,
    fatigueRisk,
    resurfacingDrift,
  };
}

export function downloadSacrednessReviewJson(
  report: SacrednessReviewReport = buildSacrednessReviewReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "sacredness-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

import { buildEmotionalIntegrityReport } from "@/lib/integrity/emotional-integrity";
import { buildArchiveSimplicityReport } from "@/lib/integrity/archive-simplicity-review";
import { buildRemovalReviewReport } from "@/lib/integrity/removal-review";
import { buildDurabilityReviewReport } from "@/lib/integrity/durability-review";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { EmotionalIntegrityReviewReport } from "@/types/emotional-integrity-layer";

/** Single founder review hub for emotional integrity and consolidation. */
export function buildEmotionalIntegrityReviewReport(): EmotionalIntegrityReviewReport {
  const entries = getMemoryEligibleEntries();
  const integrity = buildEmotionalIntegrityReport(entries);
  const deduplication = buildCallbackDeduplicationReport(entries);
  const simplicity = buildArchiveSimplicityReport();
  const removal = buildRemovalReviewReport();
  const durability = buildDurabilityReviewReport();
  const callbacks = buildCallbackQualityReviewReport(entries);

  const weakestArtificialCallbacks = callbacks.items
    .filter(
      (item) =>
        item.manualLabels.includes("felt_generic") ||
        item.rewriteFlags.includes("could_apply_to_many") ||
        item.survival.emotionalSurvivalScore < 20,
    )
    .slice(0, 10)
    .map((item) => ({
      id: item.id,
      text: item.text.slice(0, 120),
      reason: item.cutCandidate ? "Cut candidate" : "Generic or low survival",
    }));

  const emotionalOverfitting = callbacks.items
    .filter((item) => item.survival.emotionalSurvivalScore > 85 && item.manualLabels.includes("felt_generic"))
    .slice(0, 6)
    .map((item) => ({
      id: item.id,
      text: item.text.slice(0, 100),
      detail: "High score but generic — possible overfitting",
    }));

  const copyDrift = integrity.warnings
    .filter((w) => w.kind === "copy_drift" || w.kind === "overclaiming")
    .map((w) => ({ id: w.id, text: w.label, detail: w.detail }));

  const founderWarnings = [...integrity.founderWarnings];
  if (simplicity.overdesigned && !founderWarnings.includes("The archive may be becoming overdesigned.")) {
    founderWarnings.push("The archive may be becoming overdesigned.");
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: integrity.hasData || callbacks.hasData,
    integrity: { ...integrity, founderWarnings },
    deduplication,
    simplicity,
    removal,
    durability,
    weakestArtificialCallbacks,
    repetitiveStructures: deduplication.patterns.filter((p) => p.count >= 3),
    emotionalOverfitting,
    copyDrift,
    manipulationRisk: integrity.warnings.filter((w) => w.kind === "manipulation_risk"),
    monetizationTrustRisk: integrity.warnings.filter((w) => w.kind === "monetization_trust_risk"),
    sharingCringeRisk: integrity.warnings.filter((w) => w.kind === "sharing_cringe_risk"),
    callbackFatigue: integrity.warnings.filter((w) => w.kind === "callback_fatigue"),
    silenceDegradation: integrity.warnings.filter((w) => w.kind === "silence_degradation"),
  };
}

export function exportEmotionalIntegrityReviewJson(): string {
  return JSON.stringify(buildEmotionalIntegrityReviewReport(), null, 2);
}

export function downloadEmotionalIntegrityReviewJson(
  report: EmotionalIntegrityReviewReport = buildEmotionalIntegrityReviewReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "emotional-integrity-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

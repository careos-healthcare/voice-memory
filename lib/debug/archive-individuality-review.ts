import { buildArchiveIndividualityProfile } from "@/lib/identity/archive-individuality";
import { buildLongitudinalIndividualityReport } from "@/lib/identity/longitudinal-individuality";
import { assessVoiceTexture } from "@/lib/identity/voice-texture";
import { archiveHomogenizationRisk } from "@/lib/identity/personalized-restraint";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { scanAntiTemplateViolations } from "@/lib/refinement/anti-template";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRevisitSequencingReport } from "@/lib/refinement/revisit-sequencing";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveIndividualityReviewReport } from "@/types/archive-individuality";

function callbackSimilarityScore(entries: ReturnType<typeof getMemoryEligibleEntries>): number {
  const callbacks = buildCallbackQualityReviewReport(entries);
  if (callbacks.items.length < 2) return 0;

  const generic = callbacks.items.filter(
    (i) =>
      i.rewriteFlags.includes("could_apply_to_many") ||
      i.manualLabels.includes("felt_generic"),
  ).length;

  return Math.min(100, Math.round((generic / callbacks.items.length) * 100));
}

/** Founder archive individuality review — debug only. */
export function buildArchiveIndividualityReviewReport(): ArchiveIndividualityReviewReport {
  const entries = getMemoryEligibleEntries();
  const profile = buildArchiveIndividualityProfile(entries);
  const voiceTexture = assessVoiceTexture(entries);
  const longitudinal = buildLongitudinalIndividualityReport(entries);
  const dedup = buildCallbackDeduplicationReport(entries);
  const callbacks = buildCallbackQualityReviewReport(entries);
  const silence = buildSilenceTimingDebugSnapshot();
  const sequencing = buildRevisitSequencingReport();

  const antiTemplate = scanAntiTemplateViolations(
    callbacks.items.slice(0, 20).map((i) => ({ id: i.id, text: i.text })),
  );

  const uniquenessMarkers = [
    {
      id: "certainty",
      label: "Naming certainty",
      detail: `${profile.namingStyle.certaintyBand} · hedge ${profile.namingStyle.avgHedge} / direct ${profile.namingStyle.avgDirect}`,
    },
    {
      id: "pacing",
      label: "Pacing band",
      detail: `${profile.pacingStyle.band} · median gap ${profile.pacingStyle.medianEntryGapDays}d`,
    },
    {
      id: "vocab",
      label: "Vocabulary breadth",
      detail: `${profile.emotionalVocabulary.uniqueTokenCount} tokens · ${profile.emotionalVocabulary.themeCount} themes`,
    },
    {
      id: "silence",
      label: "Silence tolerance",
      detail: `Density tolerance ${profile.emotionalDensityTolerance.score} · session notes ${silence.sessionNoteCount}`,
    },
  ];

  const phrasingCollapseRisk = Math.min(
    100,
    dedup.collapsedTemplates.length * 15 + antiTemplate.length * 10,
  );

  const revisitRhythmUniqueness = Math.min(
    100,
    Math.round(
      (sequencing.recommendedSpacingDays > 7 ? 60 : 40) +
        (sequencing.revisitFatigueActive ? -25 : 20) +
        profile.pacingStyle.medianEntryGapDays * 2,
    ),
  );

  const silenceBehaviorUniqueness = Math.min(
    100,
    Math.round(
      (silence.weakNoteSuppressed ? 55 : 35) +
        (silence.ignoredCooldownActive ? 20 : 10) +
        (silence.consecutiveIgnored > 0 ? 10 : 0),
    ),
  );

  const similarity = callbackSimilarityScore(entries);
  const homogenization = archiveHomogenizationRisk(entries);

  const founderWarnings: string[] = [];
  if (profile.emotionalVocabulary.diversityScore < 35 || similarity >= 55) {
    founderWarnings.push("The product may be losing emotional specificity.");
  }
  if (homogenization >= 50 || longitudinal.converging) {
    founderWarnings.push("Different users may be starting to sound the same.");
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: profile.hasData || entries.length > 0,
    profile,
    voiceTexture,
    longitudinal,
    uniquenessMarkers,
    repeatedStructures: dedup.patterns
      .filter((p) => p.count >= 2)
      .map((p) => ({ id: p.id, label: p.label, count: p.count })),
    phrasingCollapseRisk,
    vocabularyDiversity: profile.emotionalVocabulary.diversityScore,
    revisitRhythmUniqueness,
    silenceBehaviorUniqueness,
    callbackSimilarityScore: similarity,
    founderWarnings,
  };
}

export function downloadArchiveIndividualityReviewJson(
  report: ArchiveIndividualityReviewReport = buildArchiveIndividualityReviewReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "archive-individuality-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

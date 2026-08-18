import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildSilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import {
  buildEligibleProofSnippets,
  scanOverclaimedLines,
  STATIC_QUIET_PROOF_LINES,
} from "@/lib/social-proof/emotional-proof";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import {
  findForbiddenTestimonialPhrase,
  readApprovedTestimonials,
  TESTIMONIAL_PREFERRED_PHRASES,
} from "@/lib/social-proof/testimonial-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  EmotionalLegitimacyReport,
  EmotionalLegitimacyScores,
} from "@/types/social-proof";

function clampScore(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}

function scoreTrustStrength(entries: JournalEntry[]): number {
  const approved = readApprovedTestimonials().length;
  const proof = buildEligibleProofSnippets(entries);
  const behaviorBacked = proof.filter((row) => row.source === "behavior").length;
  return clampScore(42 + approved * 8 + behaviorBacked * 10);
}

function scoreEmotionalResidue(entries: JournalEntry[]): number {
  const report = buildCallbackQualityReviewReport(entries);
  if (report.items.length === 0) return 0;
  const avg =
    report.items.reduce((sum, item) => sum + item.emotionalResidueScore, 0) / report.items.length;
  return clampScore(avg);
}

function scoreRevisitAuthenticity(entries: JournalEntry[]): number {
  const loops = buildRetentionLoopReport();
  const links = loops.revisitsCausingReflections.length;
  const revisits = loops.events.filter((event) => event.kind === "entry_revisited").length;
  return clampScore(30 + links * 12 + Math.min(revisits, 6) * 4);
}

function scoreGenericityRisk(entries: JournalEntry[]): number {
  const report = buildCallbackQualityReviewReport(entries);
  const generic = report.items.filter(
    (item) =>
      item.manualLabels.includes("felt_generic") ||
      item.rewriteFlags.includes("could_apply_to_many"),
  ).length;
  const ratio = report.items.length ? generic / report.items.length : 0;
  return clampScore(ratio * 100);
}

function scoreOverclaimRisk(entries: JournalEntry[]): number {
  const overclaimed = scanOverclaimedLines(entries).length;
  return clampScore(Math.min(100, overclaimed * 14));
}

function scoreSilenceQuality(): number {
  const snapshot = buildSilenceTimingDebugSnapshot();
  let score = 72;
  if (snapshot.ignoredCooldownActive) score -= 12;
  if (snapshot.lastTwoWithoutEngagement) score -= 10;
  if (snapshot.weakNoteSuppressed) score += 6;
  return clampScore(score);
}

function buildScores(entries: JournalEntry[]): EmotionalLegitimacyScores {
  const trustStrength = scoreTrustStrength(entries);
  const emotionalResidue = scoreEmotionalResidue(entries);
  const revisitAuthenticity = scoreRevisitAuthenticity(entries);
  const genericityRisk = scoreGenericityRisk(entries);
  const overclaimRisk = scoreOverclaimRisk(entries);
  const silenceQuality = scoreSilenceQuality();
  const overall = clampScore(
    trustStrength * 0.22 +
      emotionalResidue * 0.22 +
      revisitAuthenticity * 0.2 +
      silenceQuality * 0.16 +
      (100 - genericityRisk) * 0.1 +
      (100 - overclaimRisk) * 0.1,
  );

  return {
    trustStrength,
    emotionalResidue,
    revisitAuthenticity,
    genericityRisk,
    overclaimRisk,
    silenceQuality,
    overall,
  };
}

function believabilityScore(text: string): number {
  let score = 50;
  const lower = text.toLowerCase();
  for (const phrase of TESTIMONIAL_PREFERRED_PHRASES) {
    if (lower.includes(phrase)) score += 12;
  }
  if (findForbiddenTestimonialPhrase(text)) score -= 40;
  if (text.length > 140) score -= 8;
  if (/\b(you should|must|need to)\b/i.test(text)) score -= 15;
  return clampScore(score);
}

export function buildEmotionalLegitimacyReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EmotionalLegitimacyReport {
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const remembered = buildRememberedLaterReport(entries);
  const scores = buildScores(entries);

  const lineCandidates = [
    ...STATIC_QUIET_PROOF_LINES.map((text, index) => ({
      id: `static-${index}`,
      text,
      score: believabilityScore(text),
    })),
    ...callbackReport.items.map((item) => ({
      id: item.id,
      text: item.text,
      score: believabilityScore(item.text) + Math.round(item.emotionalResidueScore * 0.2),
    })),
    ...readApprovedTestimonials().map((row) => ({
      id: row.id,
      text: row.text,
      score: believabilityScore(row.text) + 10,
    })),
  ];

  const strongestBelievableLines = [...lineCandidates]
    .sort((a, b) => b.score - a.score)
    .slice(0, 10);

  const weakestArtificialLines = [...lineCandidates]
    .filter((row) => row.score < 45 || findForbiddenTestimonialPhrase(row.text))
    .sort((a, b) => a.score - b.score)
    .slice(0, 10)
    .map((row) => ({
      id: row.id,
      text: row.text,
      reason:
        findForbiddenTestimonialPhrase(row.text) ??
        (row.score < 35 ? "Low believability score" : "Generic or overclaimed tone"),
    }));

  const ignoredInstantlyLines = callbackReport.items
    .filter(
      (item) =>
        item.survival.emotionalSurvivalScore < 20 ||
        item.cutCandidate ||
        item.manualLabels.includes("felt_generic"),
    )
    .slice(0, 10)
    .map((item) => ({
      id: item.id,
      text: item.text,
      reason: item.cutCandidate
        ? "Cut candidate — low survival"
        : item.manualLabels.includes("felt_generic")
          ? "Felt generic in review"
          : "Low emotional survival",
    }));

  return {
    generatedAt: new Date().toISOString(),
    hasData: callbackReport.hasData,
    scores,
    strongestBelievableLines,
    weakestArtificialLines,
    rememberedLaterCallbacks: remembered.rows.slice(0, 12),
    ignoredInstantlyLines,
  };
}

export function downloadEmotionalLegitimacyJson(
  report: EmotionalLegitimacyReport = buildEmotionalLegitimacyReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `emotional-legitimacy-${report.generatedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

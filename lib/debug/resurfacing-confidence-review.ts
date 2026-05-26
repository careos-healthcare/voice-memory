import {
  assessResurfacingConfidence,
  collectResurfacingConfidenceCandidates,
} from "@/lib/revisit/resurfacing-confidence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ResurfacingConfidenceClassification,
  ResurfacingConfidenceDebugReport,
  ResurfacingConfidenceReviewRow,
  ResurfacingConfidenceVerdict,
} from "@/types/resurfacing-confidence";

function toReviewRow(verdict: ResurfacingConfidenceVerdict): ResurfacingConfidenceReviewRow {
  return {
    noteId: verdict.noteId,
    entryId: verdict.entryId ?? "",
    text: verdict.text,
    totalConfidence: verdict.totalConfidence,
    classification: verdict.classification,
    evidenceReason: verdict.evidenceReason,
    reasons: verdict.reasons,
    suppressReasons: verdict.suppressReasons,
    falsePositiveRisks: verdict.falsePositiveRisks,
    dimensions: verdict.dimensions,
    evidence: verdict.evidence,
  };
}

function countByKey(values: string[]): Array<{ reason: string; count: number }> {
  const counts = new Map<string, number>();
  for (const value of values) {
    counts.set(value, (counts.get(value) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([reason, count]) => ({ reason, count }))
    .sort((a, b) => b.count - a.count);
}

export function buildResurfacingConfidenceDebugReport(): ResurfacingConfidenceDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = collectResurfacingConfidenceCandidates(entries);
  const verdicts = candidates.map((note) => assessResurfacingConfidence(note, entries));
  const rows = verdicts.map(toReviewRow);

  const byClassification = verdicts.reduce(
    (acc, verdict) => {
      acc[verdict.classification] += 1;
      return acc;
    },
    {
      suppress: 0,
      weak: 0,
      plausible: 0,
      strong: 0,
      magic_candidate: 0,
    } satisfies Record<ResurfacingConfidenceClassification, number>,
  );

  const suppressed = rows.filter((row) => row.classification === "suppress");
  const weak = rows.filter((row) => row.classification === "weak");
  const strong = rows.filter((row) => row.classification === "strong");
  const magicCandidates = rows.filter((row) => row.classification === "magic_candidate");

  const topEvidenceReasons = countByKey(
    rows
      .map((row) => row.evidenceReason)
      .filter((reason): reason is string => Boolean(reason)),
  ).slice(0, 8);

  const falsePositiveRisks = countByKey(rows.flatMap((row) => row.falsePositiveRisks))
    .map((item) => ({ risk: item.reason, count: item.count }))
    .slice(0, 10);

  const interactionPenaltySamples = rows
    .filter(
      (row) =>
        row.dimensions.interactionReinforcementScore < 35 ||
        row.falsePositiveRisks.includes("ignored_or_dismissed"),
    )
    .sort((a, b) => a.dimensions.interactionReinforcementScore - b.dimensions.interactionReinforcementScore)
    .slice(0, 8);

  return {
    generatedAt: new Date().toISOString(),
    hasData: rows.length > 0,
    totalCandidates: rows.length,
    suppressed,
    weak,
    strong,
    magicCandidates,
    topEvidenceReasons,
    falsePositiveRisks,
    interactionPenaltySamples,
    byClassification,
  };
}

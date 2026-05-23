import type { PatternInsight } from "@/lib/patterns/pattern-engine";

export function insightConfidenceLabel(score: number): string {
  if (score >= 70) return "Strong pattern";
  if (score >= 50) return "Moderate pattern";
  return "Possible pattern";
}

export interface PatternEvidenceCounts {
  patternCount?: number;
  contradictionCount?: number;
  phraseCount?: number;
  avoidanceCount?: number;
  evolutionCount?: number;
}

/** True when ranked pattern modules surface concrete cross-entry evidence. */
export function hasStrongPatternEvidence(counts: PatternEvidenceCounts): boolean {
  return (
    (counts.patternCount ?? 0) >= 2 ||
    (counts.contradictionCount ?? 0) >= 1 ||
    (counts.phraseCount ?? 0) >= 1 ||
    (counts.avoidanceCount ?? 0) >= 1 ||
    (counts.evolutionCount ?? 0) >= 1
  );
}

export function countsFromInsights(patternInsights: PatternInsight[]): PatternEvidenceCounts {
  return {
    patternCount: patternInsights.length,
    contradictionCount: patternInsights.filter((i) => i.type === "contradiction").length,
    phraseCount: patternInsights.filter((i) => i.type === "repeated_phrase").length,
    avoidanceCount: patternInsights.filter((i) => i.type === "avoidance_signal").length,
    evolutionCount: patternInsights.filter(
      (i) => i.type === "emotional_cycle" || i.type === "improvement_signal",
    ).length,
  };
}

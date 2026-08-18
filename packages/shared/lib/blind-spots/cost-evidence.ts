import type { CostEvidenceCounts } from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

const COST_SIGNALS: Record<keyof CostEvidenceCounts, RegExp> = {
  avoidance: /\bavoid|circumvent|put off|delay|stall|indirect\b/i,
  delayedDecisions: /\bkeep waiting|eventually|monday|should have|not yet|procrastinat/i,
  quittingLanguage: /\bquit|give up|escape|run away|walk away|leave it all\b/i,
  repeatedConflict: /\bconflict|fight|argue|tension|at odds|pulls\b/i,
  emotionalSpirals: /\bspiral|overwhelm|drowning|can'?t stop|snowball|panic loop\b/i,
};

/** Count what tends to follow pattern-related reflections in later entries. */
export function buildCostEvidence(
  patternEntryIds: string[],
  entries: JournalEntry[],
): CostEvidenceCounts {
  const counts: CostEvidenceCounts = {
    avoidance: 0,
    delayedDecisions: 0,
    quittingLanguage: 0,
    repeatedConflict: 0,
    emotionalSpirals: 0,
  };

  if (patternEntryIds.length === 0) return counts;

  const sorted = [...entries]
    .filter((e) => e.reflectionPending !== true)
    .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

  const idSet = new Set(patternEntryIds);
  let lastAnchorIndex = -1;
  for (let i = 0; i < sorted.length; i += 1) {
    if (idSet.has(sorted[i]!.id)) lastAnchorIndex = i;
  }

  if (lastAnchorIndex < 0) return counts;

  const subsequent = sorted.slice(lastAnchorIndex + 1, lastAnchorIndex + 16);

  for (const entry of subsequent) {
    const blob = [
      entry.transcript,
      entry.reflection.repeatedSignal ?? "",
      entry.reflection.concreteObservation ?? "",
    ].join(" ");

    for (const key of Object.keys(COST_SIGNALS) as (keyof CostEvidenceCounts)[]) {
      if (COST_SIGNALS[key].test(blob)) {
        counts[key] += 1;
      }
    }
  }

  return counts;
}

export function hasCostEvidence(counts: CostEvidenceCounts): boolean {
  return Object.values(counts).some((n) => n > 0);
}

export function possibleCostLead(counts: CostEvidenceCounts): string | null {
  if (!hasCostEvidence(counts)) return null;
  return "Possible cost (not proof of causation): later reflections may show avoidance, delay, conflict, quitting language, or spirals — correlation only.";
}

export function formatCostEvidenceLine(counts: CostEvidenceCounts): string[] {
  const lines: string[] = [];
  if (counts.avoidance > 0) {
    lines.push(`Avoidance language may have followed ${counts.avoidance} time${counts.avoidance === 1 ? "" : "s"} in later reflections.`);
  }
  if (counts.delayedDecisions > 0) {
    lines.push(`Delayed-decision wording may have followed ${counts.delayedDecisions} time${counts.delayedDecisions === 1 ? "" : "s"}.`);
  }
  if (counts.quittingLanguage > 0) {
    lines.push(`Quitting or escape language may have followed ${counts.quittingLanguage} time${counts.quittingLanguage === 1 ? "" : "s"}.`);
  }
  if (counts.repeatedConflict > 0) {
    lines.push(`Conflict or tension language may have followed ${counts.repeatedConflict} time${counts.repeatedConflict === 1 ? "" : "s"}.`);
  }
  if (counts.emotionalSpirals > 0) {
    lines.push(`Spiral or overwhelm language may have followed ${counts.emotionalSpirals} time${counts.emotionalSpirals === 1 ? "" : "s"}.`);
  }
  return lines;
}

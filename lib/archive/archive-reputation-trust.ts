import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildEvidenceLocker } from "@/lib/archive/evidence-locker";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

function formatLifeAreasInline(areas: string[]): string | null {
  const labels = areas.slice(0, 3).map((a) => a.toLowerCase());
  if (labels.length === 0) return null;
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]}`;
  return `${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}`;
}

export function buildWhyArchiveTrustsThisLines(
  entriesInput?: JournalEntry[],
): string[] {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const belief = buildArchiveBeliefView(entries);
  const reputation = buildArchiveReputationView(entries);
  const survival = buildBeliefSurvivalView(entries);
  const locker = buildEvidenceLocker(entries);

  if (!belief || !reputation) return [];

  const lines: string[] = [];
  const seen = new Set<string>();

  const push = (text: string) => {
    const t = text.trim();
    if (!t || seen.has(t)) return;
    seen.add(t);
    assertNoCertaintyLanguage(t);
    lines.push(t);
  };

  const spread = formatLifeAreasInline(belief.evidence.lifeAreas);
  if (spread) {
    push(`This belief appears in ${spread}.`);
  }

  if (survival && survival.contradictionsSurvived >= 1) {
    push("This belief survived contradictory evidence.");
  }

  if (reputation.daysTracked >= 2) {
    push(`This belief has been tracked for ${reputation.daysTracked} days.`);
  }

  if (reputation.beliefChangesObserved >= 1) {
    push(
      `The archive has revised this belief ${reputation.beliefChangesObserved} time${reputation.beliefChangesObserved === 1 ? "" : "s"}.`,
    );
  }

  if (reputation.accuracySignals >= 1) {
    push(
      `${reputation.accuracySignals} later reflection${reputation.accuracySignals === 1 ? "" : "s"} may align with this belief.`,
    );
  }

  if (locker.items.length >= 2) {
    push("Evidence locker holds lines the archive would lose if this belief faded.");
  }

  if (belief.evidence.costEvidenceLines.length > 0) {
    push("Cost signals appear in reflections tied to this belief.");
  }

  if (belief.evidence.predictionFailureLines.length > 0) {
    push("Failed predictions are part of how this belief was tested.");
  }

  return lines.slice(0, 6);
}

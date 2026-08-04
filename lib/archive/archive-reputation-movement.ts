import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  archiveReputationLevelRank,
  buildArchiveReputationView,
} from "@/lib/archive/archive-reputation";
import { buildArchiveAccuracyView } from "@/lib/archive/archive-accuracy";
import { assertNoCertaintyLanguage } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveReputationMovementView {
  id: string;
  headline: string;
  detail: string | null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `arm-${crypto.randomUUID()}`;
  }
  return `arm-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildArchiveReputationMovement(
  entriesInput?: JournalEntry[],
): ArchiveReputationMovementView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const before = eligible(entries.slice(0, -1));
  const after = entries;
  const repBefore = buildArchiveReputationView(before);
  const repAfter = buildArchiveReputationView(after);
  const belief = buildArchiveBeliefView(after);

  if (!repAfter || !belief) return null;

  const accuracy = buildArchiveAccuracyView(after);
  const lead = accuracy?.beliefs.find((row) => row.theoryId === belief.theoryId);

  if (repBefore && archiveReputationLevelRank(repAfter.level) > archiveReputationLevelRank(repBefore.level)) {
    const headline = "Archive reputation increased.";
    assertNoCertaintyLanguage(headline);
    return { id: newId(), headline, detail: repAfter.summary };
  }

  if (lead?.status === "confirmed") {
    const headline = "New evidence strengthened this belief.";
    assertNoCertaintyLanguage(headline);
    return { id: newId(), headline, detail: lead.detail };
  }

  if (lead?.status === "challenged") {
    const headline = "Contradicting evidence lowered confidence.";
    assertNoCertaintyLanguage(headline);
    return { id: newId(), headline, detail: lead.detail };
  }

  if (
    repBefore &&
    archiveReputationLevelRank(repAfter.level) < archiveReputationLevelRank(repBefore.level)
  ) {
    const headline = "Archive reputation shifted lower after new saved moments.";
    assertNoCertaintyLanguage(headline);
    return { id: newId(), headline, detail: repAfter.summary };
  }

  return null;
}

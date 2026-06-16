import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";
import { buildArchiveStateDelta } from "@/lib/archive/archive-state-snapshot";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchivePulseView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildArchivePulse(entriesInput?: JournalEntry[]): ArchivePulseView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  const delta = buildArchiveStateDelta(entries);

  if (delta?.hasChanges) {
    const confidence = delta.rows.find((r) => r.kind === "confidence");
    if (confidence) {
      return { line: "The archive became more certain this week." };
    }
    const life = delta.rows.find((r) => r.kind === "life_areas");
    if (life) {
      return { line: "The archive expanded into a new life area." };
    }
    const reputation = delta.rows.find((r) => r.kind === "reputation");
    if (reputation) {
      return { line: "The archive's standing on this belief shifted." };
    }
    const evidence = delta.rows.find((r) => r.kind === "evidence");
    if (evidence) {
      return { line: "New evidence appeared." };
    }
    if (delta.rows.find((r) => r.kind === "belief")) {
      return { line: "The archive is reconsidering one belief." };
    }
  }

  if (!belief) return null;

  if (belief.status === "weakening" || belief.evidence.contradictingQuotes.length > 0) {
    return { line: ARCHIVE_EMOTIONAL.theoryWeakened };
  }

  if (belief.status === "under_review") {
    const recentIds = new Set(
      [...entries]
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
        .slice(0, 3)
        .map((e) => e.id),
    );
    const recentTouchesBelief = belief.evidence.supportingQuotes.some((q) =>
      recentIds.has(q.entryId),
    );
    if (!recentTouchesBelief && entries.length >= 5) {
      return { line: "The archive has not seen evidence for this recently." };
    }
    return { line: "The archive is reconsidering one belief." };
  }

  if (belief.status === "strengthening") {
    return { line: ARCHIVE_EMOTIONAL.confidenceIncreased };
  }

  if (belief.changeLines.length > 0) {
    return { line: belief.changeLines[0]!.text.replace(/^\+\s*/, "") };
  }

  return null;
}

import { buildArchivePulse } from "@/lib/archive/archive-pulse";
import { buildArchiveStateDelta } from "@/lib/archive/archive-state-snapshot";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveReasonToReturnView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function buildArchiveReasonToReturn(
  entriesInput?: JournalEntry[],
): ArchiveReasonToReturnView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const pulse = buildArchivePulse(entries);
  if (pulse?.line) {
    const line = pulse.line.replace(/^The archive /i, "Your archive ");
    return { line: line.charAt(0).toUpperCase() + line.slice(1) };
  }

  const delta = buildArchiveStateDelta(entries);
  if (!delta?.hasChanges) return null;

  const confidence = delta.rows.find((r) => r.kind === "confidence");
  if (confidence) {
    return { line: "Your archive has become more certain." };
  }

  if (delta.rows.find((r) => r.kind === "belief")) {
    return { line: "Your archive is reconsidering a belief." };
  }

  const evidence = delta.rows.find((r) => r.kind === "evidence");
  if (evidence) {
    return { line: "New evidence appeared." };
  }

  const life = delta.rows.find((r) => r.kind === "life_areas");
  if (life) {
    return { line: "Your archive expanded into a new life area." };
  }

  return { line: "Your archive changed since you last looked." };
}

import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export const EVIDENCE_EDUCATION_REFLECTION_COUNTS = [3, 4, 5, 6, 7] as const;

export type EvidenceEducationTrigger = "reflection_count" | "confidence_change";

export interface EvidenceEducationVisibility {
  show: boolean;
  reflectionCount: number;
  trigger: EvidenceEducationTrigger | null;
}

export function isEvidenceEducationReflectionCount(count: number): boolean {
  return (EVIDENCE_EDUCATION_REFLECTION_COUNTS as readonly number[]).includes(count);
}

export function hasTheoryConfidenceChange(entries: JournalEntry[]): boolean {
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = report.all[0];
  if (!lead || lead.previousConfidence === undefined) return false;
  return Math.abs(lead.confidenceDelta) >= 1;
}

export function buildEvidenceEducationVisibility(
  entriesInput?: JournalEntry[],
): EvidenceEducationVisibility {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  const { reflectionCount } = buildArchiveValueSnapshot(entries);

  if (isEvidenceEducationReflectionCount(reflectionCount)) {
    return {
      show: true,
      reflectionCount,
      trigger: "reflection_count",
    };
  }

  if (hasTheoryConfidenceChange(entries)) {
    return {
      show: true,
      reflectionCount,
      trigger: "confidence_change",
    };
  }

  return { show: false, reflectionCount, trigger: null };
}

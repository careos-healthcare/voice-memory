/**
 * Client-side prior evidence references — what the web client may send
 * to AI routes about earlier entries: stable ids and timestamps only.
 * Raw transcripts, excerpts, and reflection text never leave the entry
 * store for prompt context; the server builds a structured evidence
 * packet from these references.
 */

import type { JournalEntry } from "@/types/journal";

export interface PriorEvidenceRef {
  id: string;
  createdAt: string;
}

export const MAX_PRIOR_EVIDENCE_REFS = 5;

export function buildPriorEvidenceRefs(
  entries: JournalEntry[],
  excludeId?: string,
): PriorEvidenceRef[] {
  return entries
    .filter((entry) => entry.id !== excludeId)
    .slice(0, MAX_PRIOR_EVIDENCE_REFS)
    .map((entry) => ({ id: entry.id, createdAt: entry.createdAt }));
}

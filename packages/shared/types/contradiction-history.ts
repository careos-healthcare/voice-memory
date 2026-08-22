import type { ArchiveBeliefEvidence } from "@/types/archive-belief";

export interface ContradictionHistoryView {
  theoryId: string;
  headline: string;
  previousBelief: string;
  currentBelief: string;
  evidence: ArchiveBeliefEvidence;
  archiveExplanation: string;
}

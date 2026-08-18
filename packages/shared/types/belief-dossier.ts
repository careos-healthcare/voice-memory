import type { ArchiveBeliefEvidence } from "@/types/archive-belief";
import type { PersonalTheoryStatus } from "@/types/personal-theory";

export interface BeliefDossierView {
  theoryId: string;
  belief: string;
  confidence: number;
  status: PersonalTheoryStatus;
  statusLabel: string;
  firstAppearedLabel: string | null;
  lastChangedLabel: string | null;
  evidence: ArchiveBeliefEvidence;
  lifeAreas: string[];
  relatedBlindSpotHeadline: string | null;
  relatedExperimentLine: string | null;
  whatWouldChangeLines: string[];
}

/**
 * Archive Belief Centric Architecture — single read model for all archive surfaces.
 */
export type ArchiveBeliefObject = {
  belief: string;
  confidence: number;
  status: string;
  reputation: string;

  evidenceCount: number;
  lifeAreas: string[];

  whatChanged: string[];

  trustReasons: string[];

  timelinePoints: number;

  lastUpdated: string;
};

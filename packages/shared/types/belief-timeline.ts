export interface BeliefTimelinePoint {
  id: string;
  periodKey: string;
  periodLabel: string;
  confidence: number;
  statusLabel: string;
  note: string;
  whatChanged: string;
  evidenceQuoteCount: number;
  lifeAreas: string[];
  hasContradiction: boolean;
  hasCostEvidence: boolean;
  at: string;
}

export interface BeliefChangeTimeline {
  theoryId: string;
  points: BeliefTimelinePoint[];
}

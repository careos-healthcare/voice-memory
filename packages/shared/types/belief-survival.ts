export interface BeliefSurvivalConfidenceMovement {
  id: string;
  label: string;
  detail: string;
}

export interface BeliefSurvivalView {
  theoryId: string;
  daysAlive: number;
  reflectionsSupporting: number;
  contradictionsSurvived: number;
  firstAppearedDate: string;
  confidenceMovementHistory: BeliefSurvivalConfidenceMovement[];
  summaryLines: string[];
}

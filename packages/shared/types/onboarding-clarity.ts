export type FirstSessionFlowStepId =
  | "first_reflection"
  | "quiet_revisit"
  | "continuity_moment"
  | "archive_perception";

export type ConfusionLevel = "clear" | "uncertain" | "confused";

export interface FirstSessionFlowStep {
  id: FirstSessionFlowStepId;
  label: string;
  completedAt: string | null;
  droppedAt: string | null;
}

export interface CalmComprehensionOffer {
  id: string;
  text: string;
}

export interface FirstAhaOffer {
  entryId: string;
  text: string;
  noteId: string;
  href: string;
}

export interface OnboardingClarityDebugReport {
  generatedAt: string;
  withinTwoMinutes: boolean;
  flowSteps: FirstSessionFlowStep[];
  dropOffPoints: string[];
  confusionLevel: ConfusionLevel;
  confusionSignals: string[];
  ahaTimingHours: number | null;
  firstRevisitDelayHours: number | null;
  revisitConversion: string;
  timeToMeaningfulMomentMs: number | null;
  overwhelmingSurfaces: string[];
  ignoredCopyCount: number;
  instrumentation: Record<string, number>;
  activeComprehension: CalmComprehensionOffer | null;
  activeFirstAha: FirstAhaOffer | null;
}

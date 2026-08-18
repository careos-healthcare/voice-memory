export interface ActivationOnboardingStep {
  id: string;
  label: string;
  body: string;
}

export type PersonalisationProgressTier = 1 | 3 | 7 | 14;

export interface PersonalisationProgressState {
  tier: PersonalisationProgressTier;
  line: string;
}

export interface ActivationGuidanceCopyExample {
  id: string;
  message: string;
  whenShown: string;
}

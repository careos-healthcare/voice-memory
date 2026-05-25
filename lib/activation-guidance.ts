import { ONBOARDING_ACTIVATION } from "@/lib/onboarding/onboarding-copy";
import type {
  ActivationGuidanceCopyExample,
  ActivationOnboardingStep,
  PersonalisationProgressState,
  PersonalisationProgressTier,
} from "@/types/activation-guidance";

export const ACTIVATION_LEAD = ONBOARDING_ACTIVATION.lead;

export const ACTIVATION_QUIET_EARLY = ONBOARDING_ACTIVATION.quietEarly;

export const ACTIVATION_WHY_RETURN = ONBOARDING_ACTIVATION.whyReturn;

export const ACTIVATION_PATTERNS = ONBOARDING_ACTIVATION.stepReturn;

export const ACTIVATION_CONVERSATION = ONBOARDING_ACTIVATION.finish;

export const ACTIVATION_ONBOARDING_STEPS: ActivationOnboardingStep[] = [
  {
    id: "record",
    label: "Record",
    body: ONBOARDING_ACTIVATION.stepRecord,
  },
  {
    id: "return",
    label: "Return",
    body: ONBOARDING_ACTIVATION.stepReturn,
  },
  {
    id: "backup",
    label: "Optional",
    body: ONBOARDING_ACTIVATION.stepBackup,
  },
];

const PROGRESS_LINES: Record<PersonalisationProgressTier, string> = {
  1: "A first note saved.",
  3: "Links between days may appear.",
  7: "Shifts may start to show.",
  14: "Your past words feel familiar.",
};

const PROGRESS_THRESHOLDS: PersonalisationProgressTier[] = [14, 7, 3, 1];

export const ACTIVATION_GUIDANCE_COPY_EXAMPLES: ActivationGuidanceCopyExample[] = [
  { id: "lead", message: ACTIVATION_LEAD, whenShown: "First-run onboarding header" },
  {
    id: "quiet-early",
    message: ACTIVATION_QUIET_EARLY,
    whenShown: "First-run onboarding reassurance",
  },
  {
    id: "why-return",
    message: ACTIVATION_WHY_RETURN,
    whenShown: "First-run onboarding — why return",
  },
  {
    id: "patterns",
    message: ACTIVATION_PATTERNS,
    whenShown: "First-run onboarding — older reflections return",
  },
  ...Object.entries(PROGRESS_LINES).map(([tier, message]) => ({
    id: `progress-${tier}`,
    message,
    whenShown: `Personalisation progress at ${tier} reflection threshold`,
  })),
];

export function getPersonalisationProgress(
  entryCount: number,
): PersonalisationProgressState | null {
  if (entryCount < 1) return null;

  for (const tier of PROGRESS_THRESHOLDS) {
    if (entryCount >= tier) {
      return { tier, line: PROGRESS_LINES[tier] };
    }
  }

  return null;
}

/** Hide progress line once the archive is well past the guidance window. */
export function shouldShowPersonalisationProgress(entryCount: number): boolean {
  return entryCount >= 1 && entryCount <= 20;
}

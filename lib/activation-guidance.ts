import type {
  ActivationGuidanceCopyExample,
  ActivationOnboardingStep,
  PersonalisationProgressState,
  PersonalisationProgressTier,
} from "@/types/activation-guidance";

export const ACTIVATION_LEAD =
  "VoiceMemory gets more personal as your archive grows.";

export const ACTIVATION_QUIET_EARLY =
  "Early reflections may feel quiet. That is intentional.";

export const ACTIVATION_PATTERNS =
  "After a few entries, it starts remembering you.";

export const ACTIVATION_CONVERSATION =
  "This is a remembered conversation — not generic advice.";

export const ACTIVATION_ONBOARDING_STEPS: ActivationOnboardingStep[] = [
  {
    id: "day-one",
    label: "Day 1",
    body: "It listens and saves your reflection on this device.",
  },
  {
    id: "after-three",
    label: "After 3 reflections",
    body: "It starts noticing what returns.",
  },
  {
    id: "after-seven",
    label: "After 7+ reflections",
    body: "It can show what changed, faded, returned, and became clearer.",
  },
];

const PROGRESS_LINES: Record<PersonalisationProgressTier, string> = {
  1: "A first memory.",
  3: "Threads can start appearing.",
  7: "Changes may begin to surface.",
  14: "Your archive is becoming familiar.",
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
    id: "patterns",
    message: ACTIVATION_PATTERNS,
    whenShown: "First-run onboarding — continuity over time",
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

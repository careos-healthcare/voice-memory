import type {
  ActivationGuidanceCopyExample,
  ActivationOnboardingStep,
  PersonalisationProgressState,
  PersonalisationProgressTier,
} from "@/types/activation-guidance";

export const ACTIVATION_LEAD =
  "The more you talk, the more it picks up on what keeps coming back.";

export const ACTIVATION_QUIET_EARLY =
  "Early days may feel quiet. That is fine.";

export const ACTIVATION_PATTERNS =
  "After a few entries, older words start to echo back.";

export const ACTIVATION_CONVERSATION =
  "Keep going — it learns your voice over time.";

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
    body: "It can show what changed, faded, and came back.",
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

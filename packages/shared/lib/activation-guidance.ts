import {
  ARCHIVE_ONBOARDING_RECORD_CTA,
  ARCHIVE_ONBOARDING_SCREENS,
} from "@/lib/onboarding/archive-onboarding-copy";
import type {
  ActivationGuidanceCopyExample,
  ActivationOnboardingStep,
  PersonalisationProgressState,
  PersonalisationProgressTier,
} from "@/types/activation-guidance";

/** @deprecated Archive onboarding uses headlines only — no separate lead block. */
export const ACTIVATION_LEAD = ARCHIVE_ONBOARDING_SCREENS[0]!.headline;

/** @deprecated Removed from UI — kept for internal reports only. */
export const ACTIVATION_EVOLVING_VIEW = "";

export const ACTIVATION_QUIET_EARLY = "";

export const ACTIVATION_WHY_RETURN = ARCHIVE_ONBOARDING_SCREENS[0]!.headline;

export const ACTIVATION_PATTERNS = ARCHIVE_ONBOARDING_SCREENS[3]!.headline;

export const ACTIVATION_CONVERSATION = ARCHIVE_ONBOARDING_RECORD_CTA;

export const ACTIVATION_ONBOARDING_STEPS: ActivationOnboardingStep[] =
  ARCHIVE_ONBOARDING_SCREENS.map((screen) => ({
    id: screen.id,
    label: screen.headline,
    body: "",
  }));

const PROGRESS_LINES: Record<PersonalisationProgressTier, string> = {
  1: "A first note saved.",
  3: "Links between days may appear.",
  7: "Shifts may start to show.",
  14: "Your past words feel familiar.",
};

const PROGRESS_THRESHOLDS: PersonalisationProgressTier[] = [14, 7, 3, 1];

export const ACTIVATION_GUIDANCE_COPY_EXAMPLES: ActivationGuidanceCopyExample[] =
  ARCHIVE_ONBOARDING_SCREENS.map((screen) => ({
    id: screen.id,
    message: screen.headline,
    whenShown: `Archive onboarding screen — ${screen.id}`,
  }));

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

export function shouldShowPersonalisationProgress(entryCount: number): boolean {
  return entryCount >= 1 && entryCount <= 20;
}

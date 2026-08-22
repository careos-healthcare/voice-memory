/**
 * Archive onboarding — five screens, under 15 seconds. No feature or subsystem copy.
 */

export type ArchiveOnboardingScreen = {
  id: string;
  headline: string;
};

export const ARCHIVE_ONBOARDING_SCREENS: readonly ArchiveOnboardingScreen[] = [
  {
    id: "repeating",
    headline: "Your archive keeps track of what keeps repeating.",
  },
  {
    id: "evidence",
    headline: "Every reflection becomes evidence.",
  },
  {
    id: "beliefs",
    headline: "Over time your archive forms beliefs.",
  },
  {
    id: "change",
    headline: "Those beliefs change.",
  },
  {
    id: "record",
    headline: "Record your first reflection.",
  },
] as const;

export const ARCHIVE_ONBOARDING_SCREEN_COUNT = ARCHIVE_ONBOARDING_SCREENS.length;

export const ARCHIVE_ONBOARDING_RECORD_CTA = ARCHIVE_ONBOARDING_SCREENS[4]!.headline;

/** @deprecated use ARCHIVE_ONBOARDING_SCREENS */
export const ARCHIVE_ONBOARDING_HEADLINES = ARCHIVE_ONBOARDING_SCREENS.map((s) => s.headline);

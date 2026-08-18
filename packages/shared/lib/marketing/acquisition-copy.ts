/** App Store / Play Store acquisition copy — human, private, non-coaching. */

import {
  APP_DESCRIPTION_SHORT,
  EXPORT_TRUST_FOOTER,
  NOT_AI_JOURNAL_LINE,
  PRODUCT_WEDGE_LINE,
  WEDGE_RESURFACING,
} from "@/lib/product-copy";

export const SHORT_APP_DESCRIPTION = APP_DESCRIPTION_SHORT;

export const FULL_APP_DESCRIPTION = `${NOT_AI_JOURNAL_LINE} ${PRODUCT_WEDGE_LINE}

Talk naturally for a minute or two. Your audio and transcript stay on this device. Over time, ArchiveMe brings back words you forgot you were repeating — from your own voice, not therapy.

What you can do:
• Record voice reflections in a quiet, private space
• Revisit past entries and replay your own voice
• Notice what keeps returning — without scores or pressure
• Export your archive anytime
• Choose encrypted backup if you want a second copy

What ArchiveMe is not:
Not therapy. Not coaching. Not a productivity system. No diagnosis, no performance dashboard, no pressure to record every day.

Local-first. Your words stay yours.`;

/** Apple App Store — 100 characters max, comma-separated, no spaces after commas. */
export const APP_STORE_KEYWORDS =
  "voice journal,private journal,audio diary,voice diary,journal by voice,revisit,reflections,private thoughts,hear yourself,calm";

/** Google Play — natural phrases for description indexing (also used in coverage checks). */
export const PLAY_STORE_KEYWORDS = [
  "voice journal",
  "private journal",
  "audio journal",
  "voice diary",
  "speak your thoughts",
  "private voice notes",
  "revisit old entries",
  "hear yourself again",
  "personal reflections",
  "on-device journal",
  "export journal",
  "encrypted backup",
  "quiet journaling",
  "return to past thoughts",
] as const;

export type ScreenshotSetId = "emotional" | "privacy" | "revisit" | "continuity";

export interface ScreenshotSet {
  id: ScreenshotSetId;
  label: string;
  /** Max 6 screens, max 7 words each headline */
  headlines: readonly string[];
}

export const SCREENSHOT_SETS: readonly ScreenshotSet[] = [
  {
    id: "emotional",
    label: "Emotional",
    headlines: [
      "Hear yourself again",
      "Speak what matters today",
      "Your voice, kept private",
      WEDGE_RESURFACING.pastWordsMatch,
      "Notice what repeats",
      "Return when you are ready",
    ],
  },
  {
    id: "privacy",
    label: "Privacy",
    headlines: [
      "Private voice reflections",
      "Stays on your device",
      "Optional encrypted backup",
      "Export your words anytime",
      "No feeds. No scores.",
      "Your archive stays yours",
    ],
  },
  {
    id: "revisit",
    label: "Revisit",
    headlines: [
      "Past reflections resurface",
      "Open what still fits",
      "Hear your older voice",
      "Continue the thread",
      "Bookmark what matters",
      "Come back calmer",
    ],
  },
  {
    id: "continuity",
    label: "Continuity",
    headlines: [
      "Your voice over time",
      WEDGE_RESURFACING.forgottenPatterns,
      "What faded. What stayed.",
      "A few lines each week",
      "Save what to return to",
      "Remember without performing",
    ],
  },
] as const;

/** Flat map for backward-compatible export name. */
export const SCREENSHOT_HEADLINES: Record<ScreenshotSetId, readonly string[]> = {
  emotional: SCREENSHOT_SETS[0].headlines,
  privacy: SCREENSHOT_SETS[1].headlines,
  revisit: SCREENSHOT_SETS[2].headlines,
  continuity: SCREENSHOT_SETS[3].headlines,
};

export const ONBOARDING_HOOKS = [
  "A private place to hear yourself again.",
  "Speak what you are actually thinking.",
  "Your reflections stay on this device.",
  WEDGE_RESURFACING.pastWordsMatch,
  "No streaks. No scores. Return when it matters.",
] as const;

export const TRUST_LINES = [
  "Private by default — your reflections stay on this device.",
  "Not therapy, not coaching, not a productivity app.",
  "Export your archive anytime.",
  "Encrypted backup is optional.",
  "Delete individual entries or wipe local data anytime.",
] as const;

export const REVIEW_RESPONSE_TEMPLATES = {
  grateful:
    "Thank you for sharing this — it means a lot that ArchiveMe felt worth your time. If something confused you or broke, hello@archiveme.app reaches us directly.",
  privacyQuestion:
    "Your reflections stay on your device unless you turn on encrypted backup. We do not run a cloud journal database. More detail is on the Privacy page in the app.",
  revisitConfusion:
    "Older reflections sometimes appear again when they still connect to what you said recently — you can open them, ignore them, or record a follow-up. Both are fine.",
  notTherapy:
    `${NOT_AI_JOURNAL_LINE} Not therapy or medical advice. If you are in crisis, please contact local emergency services or a trusted helpline.`,
  featureRequest:
    "Thank you — we are keeping the app quiet on purpose, but we read every note. hello@archiveme.app if you want to share more context.",
  bugReport:
    "Sorry this got in your way. If you email hello@archiveme.app with what you were doing, we will look into it.",
} as const;

export const NOTIFICATION_COPY_EXAMPLES = [
  WEDGE_RESURFACING.pastWordsMatch,
  "You saved something to return to.",
  "Your voice from last month is still here.",
] as const;

/** Words that improve clarity scores when present in user-facing acquisition copy. */
export const PREFERRED_ACQUISITION_WORDS = [
  "private",
  "voice",
  "reflection",
  "device",
  "export",
  "backup",
  "revisit",
  "hear yourself",
  "local-first",
  "encrypted",
  "your words",
  "past reflections",
  "forgotten",
  "repeating",
] as const;

export const ACQUISITION_FOOTER = EXPORT_TRUST_FOOTER;

/** Abstract or internal vocabulary — flagged in acquisition review & validation. */
export const FORBIDDEN_ABSTRACT_PHRASES = [
  "longitudinal",
  "continuity intelligence",
  "archive graph",
  "emotional AI",
  "identity engine",
  "memory system",
  "reflection engine",
  "cognitive",
  "behavioral intelligence",
  "pattern engine",
  "insight engine",
  "memory intelligence",
  "reflective mirror",
  "emotional continuity",
  "living resurfacing",
  "voice identity",
  "emotional chapter",
  "intelligence layer",
] as const;

export const ACQUISITION_COPY_BUNDLE = {
  shortDescription: SHORT_APP_DESCRIPTION,
  fullDescription: FULL_APP_DESCRIPTION,
  appStoreKeywords: APP_STORE_KEYWORDS,
  playStoreKeywords: [...PLAY_STORE_KEYWORDS],
  screenshotSets: SCREENSHOT_SETS.map((set) => ({ ...set, headlines: [...set.headlines] })),
  onboardingHooks: [...ONBOARDING_HOOKS],
  trustLines: [...TRUST_LINES],
  reviewResponseTemplates: { ...REVIEW_RESPONSE_TEMPLATES },
  notificationExamples: [...NOTIFICATION_COPY_EXAMPLES],
} as const;

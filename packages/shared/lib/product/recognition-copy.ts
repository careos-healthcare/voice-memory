/** Short recognition-first copy — almost disappears, reads in under two seconds. */

import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

export const RECOGNITION_COPY = {
  appSubtitle: "Your words, kept privately.",
  appTagline: LANDING_3_DAY_CHALLENGE.hero,
  appLead: LANDING_3_DAY_CHALLENGE.subhero,
  wedge: "You said this before.",
  notAiJournal: "Your words stay yours — private, on this device.",
  homepageSpeak: LANDING_3_DAY_CHALLENGE.steps[0]!.title,
  homepageRemember: LANDING_3_DAY_CHALLENGE.steps[1]!.title,
  homepageReturn: LANDING_3_DAY_CHALLENGE.steps[2]!.title,
  homepageCta: LANDING_3_DAY_CHALLENGE.recorderIntro,
  firstSave:
    "Saved. Say one more later — ArchiveMe can start noticing what comes back.",
  nothingReturned: "Nothing has returned yet. Keep speaking naturally.",
  journalLead: "What came back, then what you said.",
  memoryTitle: "What returned",
} as const;

/** Banned in user-facing surfaces — product/system voice. */
export const BANNED_PRODUCT_VOICE = [
  "voice notes",
  "voice note app",
  "memory resurfacing",
  "continuity intelligence",
  "archive resonance",
  "intelligence engine",
  "validator",
  "validators",
  "architecture",
  "archiveme brings back phrases",
  "ai summary",
  "ai-generated",
  "speaker expresses",
  "pattern analysis",
  "insight engine",
] as const;

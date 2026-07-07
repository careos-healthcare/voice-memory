import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

/** Pro positioning — timeline continuity, not export/productivity. */

export const PRO_HEADLINE = LANDING_3_DAY_CHALLENGE.proSection.headline;

export const PRO_DESCRIPTION = LANDING_3_DAY_CHALLENGE.proSection.paidReason;

export const PRO_FEATURE_BULLETS = [
  "Full pattern timeline across your archive",
  "Correction history when something no longer fits",
  "Changing current weight as evidence shifts",
  "Longer evidence trail over weeks and months",
  "Monthly private report when eligible",
  "Backup and continuity when you sign in",
] as const;

export const PRO_GATE_UNLIMITED_ARCHIVE = {
  title: "Full timeline continuity is part of Pro",
  detail:
    "Free shows the first proof. Pro keeps the full timeline as it grows — resurfacing, search, and return threads across your history.",
  feature: "unlimited_archive",
} as const;

export const PRO_GATE_DEEPER_RESURFACING = {
  title: "Full-history timeline is part of Pro",
  detail:
    "Pro draws return threads and callbacks from your entire archive — not only recent saves.",
  feature: "deeper_resurfacing",
} as const;

export const PRO_GATE_EXPORT = {
  title: "Longer timeline and exports are part of Pro",
  detail:
    "Pro keeps the full timeline as it grows, with export when you need a portable copy.",
  feature: "export_reports",
} as const;

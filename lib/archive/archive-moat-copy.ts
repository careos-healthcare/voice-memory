/** Copy guard for competitor-lesson retention surfaces — no therapy/coaching tone. */
export const ARCHIVE_MOAT_FORBIDDEN = [
  /\btherapy\b/i,
  /\bdiagnosis\b/i,
  /\bcure\b/i,
  /\btreatment\b/i,
  /\bhealing journey\b/i,
  /\bcoach\b/i,
  /\bgreat job\b/i,
  /\bproud of you\b/i,
  /\byou should\b/i,
] as const;

export const ARCHIVE_MOAT_PREFERRED_HINTS = [
  "archive",
  "evidence",
  "belief",
  "confidence",
  "changed",
  "under review",
  "comparison point",
  "hard to rebuild",
  "harder to fool",
] as const;

export const ARCHIVE_MOAT_SCAN_FILES = [
  "lib/archive/session-movement-summary-copy.ts",
  "lib/archive/archive-asset-value-copy.ts",
  "lib/archive/archive-maturity-copy.ts",
  "lib/archive/effort-compounds-copy.ts",
  "lib/archive/what-archive-can-answer-copy.ts",
  "lib/archive/hard-to-reproduce-proof.ts",
] as const;
